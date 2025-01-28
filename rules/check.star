load("rules:package_tool.star", "package_tool")
load("rules:tool_provider.star", "ToolProvider", "tool_environment")
load("util:batch.star", "make_batches")
load("util:execute.star", "check_exit_code")
load("util:fs.star", "walk_up_to_find_file", "walk_up_to_find_file2")
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

# Information we cache

ExecutionContext = record(
    stdout = str,
    stderr = str,
    exit_code = int,
    output_file_contents = str | None,
)

def _execution_context_to_json(ctx: ExecutionContext) -> str:
    return json.encode(ctx)

def _execution_context_from_json(json_str: str) -> ExecutionContext:
    value = json.decode(json_str)
    return ExecutionContext(
        stdout = value["stdout"],
        stderr = value["stderr"],
        exit_code = value["exit_code"],
        output_file_contents = value["output_file_contents"],
    )

# Parse

ParseContext = record(
    paths = Paths,
    run_from = str,
    targets = list[str],
    scratch_dir = str | None,
    execution = ExecutionContext,
)

# CommandLineReplacements

UpdateCommandLineReplacementsContext = record(
    paths = Paths,
    map = dict[str, str],
    targets = list[str],
)

UpdateRunFromContext = record(
    paths = Paths,
    scratch_dir = str | None,
    targets = list[str],
    run_from = str,
)

# CacheEntry

_CacheEntry = record(
    lru = disk_lru.DiskLru,
    bucket = str,
    key = str,
)

def _make_cache_entry(paths: Paths, target: str, affects_cache: list[str], *args) -> _CacheEntry:
    lru = disk_lru.DiskLru(fs.join(paths.repo_cache_dir, "results"), 10)

    bucket_hasher = blake3.Blake3()
    bucket_hasher.update(json.encode(target))
    cache_bucket = bucket_hasher.finalize_hex(length = 16)
    key_hasher = blake3.Blake3()
    key_hasher.update(fs.read_file(fs.join(paths.workspace_dir, target)))
    for affect in affects_cache:
        file_path = walk_up_to_find_file2(target, affect)
        if file_path != None:
            key_hasher.update(file_path)
            key_hasher.update(fs.read_file(file_path))
    key_hasher.update(json.encode(args))
    cache_key = key_hasher.finalize_hex(length = 16)

    return _CacheEntry(
        lru = lru,
        bucket = cache_bucket,
        key = cache_key,
    )

def _lookup_cache_entry(entry: _CacheEntry) -> ExecutionContext | None:
    cached_json = entry.lru.find(entry.bucket, entry.key)
    if cached_json:
        cached_result = _execution_context_from_json(cached_json)
        if not cached_result:
            entry.lru.remove(entry.bucket, entry.key)
        return cached_result

def _save_cache_entry(entry: _CacheEntry, result: ExecutionContext, cache_ttl: int):
    entry.lru.insert(entry.bucket, entry.key, _execution_context_to_json(result), cache_ttl)

def _execute_command(
        command: list[str],
        env: dict[str, str],
        current_dir: str,
        timeout_ms: int,
        output_file: str | None) -> ExecutionContext:
    result = process.execute(
        command = command,
        env = env,
        current_dir = current_dir,
        timeout_ms = timeout_ms,
    )

    output_file_contents = None
    if output_file:
        output_file_contents = fs.read_file(output_file)

    return ExecutionContext(
        stdout = result.stdout,
        stderr = result.stderr,
        exit_code = result.exit_code,
        output_file_contents = output_file_contents,
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
        output_file: bool = False,
        scratch_dir: bool = False,
        batch_size: int = 64,
        bisect: bool = True,
        update_run_from: None | typing.Callable = None,
        bucket: typing.Callable = bucket_by_workspace,
        update_command_line_replacements: None | typing.Callable = None,
        affects_cache = [],
        timeout_ms = 300000,  # 5 minutes
        cache_results = False,
        cache_ttl = 60 * 60 * 24,  # 24 hours
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

        if output_file:
            output_dir = ctx.temp_dir()
            replacements["output_file"] = shlex.quote(fs.join(output_dir, "output"))

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
        cache_entry = None
        cached_execution = None
        if cache_results and len(targets) == 1:
            cache_entry = _make_cache_entry(ctx.paths(), targets[0], affects_cache, run_from, command, env)
            cached_execution = _lookup_cache_entry(cache_entry)

        # Execute the command.
        if cached_execution:
            execution = cached_execution
        else:
            execution = _execute_command(split_command, env, run_from, timeout_ms, replacements.get("output_file"))

        # Check the exit code of the command.
        error_message = check_exit_code(execution.exit_code, success_codes, error_codes)
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
        if cache_entry and not cached_execution:
            _save_cache_entry(cache_entry, execution, cache_ttl)

        # Parse the output of the command.
        tarif = parse(ParseContext(
            paths = ctx.paths(),
            run_from = run_from,
            targets = targets,
            scratch_dir = replacements.get("scratch_dir"),
            execution = execution,
        ))
        ctx.add_tarif(json.encode(tarif))

    native.string(name = name + "_command", default = command)

    native.check(
        name = name,
        impl = impl,
        files = files,
        inputs = {
            "tool": tool,
            "command": ":" + name + "_command",
        },
    )
