load("rules:package_tool.star", "package_tool")
load("rules:tool_provider.star", "ToolProvider", "tool_environment")
load("util:batch.star", "make_batches")
load("util:execute.star", "check_exit_code")
load("util:fs.star", "walk_up_to_find_file")
load("util:tarif.star", "tarif")

# Bucket

BucketContext = record(
    files = list[str],
)

# Bucket all files into a single bucket to run from the workspace root.
def bucket_by_workspace(ctx: BucketContext) -> dict[str, list[str]]:
    return {".": ctx.files}

# Bucket files to run from the directory containing the specified file.
def _bucket_by_file(target: str, ctx: BucketContext) -> dict[str, list[str]]:
    directories = {}
    for file in ctx.files:
        directory = walk_up_to_find_file(file, target) or "."
        if directory not in directories:
            directories[directory] = []
        directories[directory].append(fs.relative_to(file, directory))
    return directories

def bucket_by_file(target: str):
    return partial(_bucket_by_file, target)

# Bucket files to run from the directory containing the specified file on each directory containing that file.
def _bucket_directories_by_file(target: str, ctx: BucketContext) -> dict[str, list[str]]:
    directories = set()
    for file in ctx.files:
        directory = walk_up_to_find_file(file, target) or "."
        directories.add(directory)
    return {".": list(directories)}

def bucket_directories_by_file(target: str):
    return partial(_bucket_directories_by_file, target)

# Parse

ParseContext = record(
    paths = Paths,
    targets = list[str],
    result = process.ExecuteResult,
    run_from = str,
    scratch_dir = str | None,
)

# CommandLineReplacements

UpdateCommandLineReplacementsContext = record(
    paths = Paths,
    map = dict[str, str],
    targets = list[str],
)

UpdateRunFromContext = record(
    paths = Paths,
    scratch_dir = str,
    targets = list[str],
    run_from = str,
)

# Defeines a check that runs a command on a set of files and parses the output.
# Also defines a target `command` that the user can override from the provided default.
def check(
        name: str,
        command: str,
        files: list[str],
        tool: str,
        parse: typing.Callable,
        success_codes: list[int] = [],
        error_codes: list[int] = [],
        scratch_dir: bool = False,
        batch_size: int = 64,
        bisect: bool = True,
        update_run_from: None | typing.Callable = None,
        bucket: typing.Callable = bucket_by_workspace,
        update_command_line_replacements: None | typing.Callable = None,
        timeout_ms = 300000,  # 5 minutes
        cache_results = False,
        cache_ttl = 0,
        target_description: str = "targets"):
    label = native.label_string(":" + name)

    def impl(ctx: CheckContext, result: FilesResult):
        buckets = bucket(BucketContext(files = result.files))
        for (run_from, targets) in buckets.items():
            batch(ctx, run_from, targets, batch_size)

    def batch(ctx: CheckContext, run_from: str, targets: list[str], current_batch_size: int):
        for targets in make_batches(targets, current_batch_size):
            description = "{label} ({num_files} {target_description})".format(
                label = label,
                num_files = len(targets),
                target_description = target_description,
            )
            ctx.spawn(description = description, weight = len(targets)).then(run, ctx, run_from, targets)

    def run(ctx: CheckContext, run_from: str, targets: list[str]):
        replacements = {
            "targets": shlex.join(targets),
        }
        if scratch_dir:
            temp_dir = ctx.temp_dir()
            replacements["scratch_dir"] = shlex.quote(temp_dir)

        if update_command_line_replacements:
            update_command_line_replacements(UpdateCommandLineReplacementsContext(
                paths = ctx.paths(),
                map = replacements,
                targets = targets,
            ))

        if update_run_from:
            run_from = update_run_from(UpdateRunFromContext(
                paths = ctx.paths(),
                scratch_dir = replacements.get("scratch_dir"),
                targets = targets,
                run_from = run_from,
            ))

        split_command = shlex.split(command.format(**replacements))
        env = tool_environment([ctx.inputs().tool[ToolProvider]])

        # Check the cache for the result of the command.
        lru = None
        cache_bucket  = None
        cache_key = None
        cached_result = None
        if cache_results and len(targets) == 1:
            target = targets[0]

            lru = disk_lru.DiskLru(fs.join(ctx.paths().repo_cache_dir, "results"), 10)

            data = fs.read_file(fs.join(ctx.paths().workspace_dir, target))
            bucket_hasher = blake3.Blake3()
            bucket_hasher.update(json.encode(target))
            cache_bucket = bucket_hasher.finalize_hex(length = 16)
            key_hasher = blake3.Blake3()
            key_hasher.update(json.encode([
                data,
                split_command,
                env,
                run_from,
                target,
            ]))
            cache_key = key_hasher.finalize_hex(length = 16)

            cached_json = lru.find(cache_bucket, cache_key)
            if cached_json:
                cached_result = process.try_execute_result_from_json(cached_json)
                if not cached_result:
                    lru.remove(cache_bucket, cache_key)

        # Execute the command.
        if cached_result:
            result = cached_result
        else:
            result = process.execute(
                command = split_command,
                env = env,
                current_dir = run_from,
                timeout_ms = timeout_ms
            )

        # Check the exit code of the command.
        error_message = check_exit_code(result, success_codes, error_codes)
        if error_message:
            if len(targets) == 1 or not bisect:
                fail(error_message)
            else:
                # If a batch fails, then bisect by a factor of 8.
                bisect_factor = 8
                batch_size = (len(targets) + bisect_factor - 1) // bisect_factor
                batch(ctx, run_from, targets, batch_size)
                return

        # Cache the result of the command.
        if lru and cache_key and cache_bucket and not cached_result:
            lru.insert(cache_bucket, cache_key, json.encode(result), cache_ttl)

        # Parse the output of the command.
        tarif = parse(ParseContext(
            paths = ctx.paths(),
            result = result,
            run_from = run_from,
            targets = targets,
            scratch_dir = replacements.get("scratch_dir"),
        ))
        ctx.add_tarif(json.encode(tarif))

    native.string(name = "command", default = command)

    native.check(
        name = name,
        impl = impl,
        files = files,
        inputs = {
            "tool": tool,
            "command": ":command",
        },
    )
