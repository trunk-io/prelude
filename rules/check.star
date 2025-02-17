load("rules:package_tool.star", "package_tool")
load("rules:tool_provider.star", "ToolProvider", "tool_environment")
load("util:batch.star", "make_batches")
load("util:execute.star", "check_exit_code")
load("util:fs.star", "walk_up_to_find_dir_of_files", "walk_up_to_find_file")
load("util:tarif.star", "tarif")

# Bucket

BucketContext = record(
    paths = list[str],
)

# Bucket all files into a single bucket to run from the workspace root.
def bucket_by_workspace(ctx: BucketContext) -> dict[str, list[str]]:
    return {".": ctx.paths}

# Bucket files to run from the directory containing the specified file.
def _bucket_by_files(targets: list[str], ctx: BucketContext) -> dict[str, list[str]]:
    directories = {}
    for file in ctx.paths:
        directory = walk_up_to_find_dir_of_files(file, targets) or "."
        if directory not in directories:
            directories[directory] = []
        directories[directory].append(fs.relative_to(file, directory))
    return directories

def bucket_by_files(targets: list[str]):
    return partial(_bucket_by_files, targets)

def bucket_by_file(target: str):
    return partial(_bucket_by_files, [target])

# Bucket files to run from the directory containing the specified file.
# If the file doesn't exist, then ignore.
def _bucket_by_files_or_ignore(targets: list[str], ctx: BucketContext) -> dict[str, list[str]]:
    directories = {}
    for path in ctx.paths:
        directory = walk_up_to_find_dir_of_files(path, targets)
        if directory:
            if directory not in directories:
                directories[directory] = []
            directories[directory].append(fs.relative_to(path, directory))
    return directories

def bucket_by_files_or_ignore(targets: list[str]):
    return partial(_bucket_by_files_or_ignore, targets)

def bucket_by_file_or_ignore(target: str):
    return partial(_bucket_by_files_or_ignore, [target])

# Bucket files to run from the directory containing the specified file on each directory containing that file.
def _bucket_directories_by_files(targets: list[str], ctx: BucketContext) -> dict[str, list[str]]:
    directories = set()
    for path in ctx.paths:
        directory = walk_up_to_find_dir_of_files(path, targets) or "."
        directories.add(directory)
    return {".": list(directories)}

def bucket_directories_by_files(targets: list[str]):
    return partial(_bucket_directories_by_files, targets)

def bucket_directories_by_file(target: str):
    return partial(_bucket_directories_by_files, [target])

# Bucket files to run from the parent directory of each file.
def bucket_by_dir(ctx: BucketContext) -> dict[str, list[str]]:
    directories = {}
    for path in ctx.paths:
        directory = fs.dirname(path)
        if directory not in directories:
            directories[directory] = []
        directories[directory].append(fs.filename(path))
    return directories

# Run on the directories containing the files.
def bucket_dirs_of_files(ctx: BucketContext) -> dict[str, list[str]]:
    directories = set()
    for path in ctx.paths:
        directory = fs.dirname(path)
        directories.add(directory)
    return {".": list(directories)}

# Read from

ReadOutputContext = record(
    run_from = str,
    targets = list[str],
    scratch_dir = str | None,
    execute_result = process.ExecuteResult,
)

def _read_output_from_scratch_dir(file: str, ctx: ReadOutputContext) -> str | None:
    path = fs.join(ctx.scratch_dir, file)
    if not fs.exists(path):
        return None
    return fs.read_file(fs.join(ctx.scratch_dir, file))

def read_output_from_scratch_dir(file: str):
    return partial(_read_output_from_scratch_dir, file)

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
        file_path = walk_up_to_find_file(target, affect)
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

def _save_cache_entry(entry: _CacheEntry, result: ExecutionContext, cache_ttl_s: int):
    entry.lru.insert(entry.bucket, entry.key, _execution_context_to_json(result), cache_ttl_s)

def _execute_command(
        command: list[str],
        env: dict[str, str],
        current_dir: str,
        scratch_dir: str | None,
        timeout_ms: int,
        read_output_file: None | typing.Callable) -> ExecutionContext:
    execute_result = process.execute(
        command = command,
        env = env,
        current_dir = current_dir,
        timeout_ms = timeout_ms,
    )

    output_file_contents = None
    if read_output_file:
        output_file_contents = read_output_file(ReadOutputContext(
            run_from = current_dir,
            targets = [],
            scratch_dir = scratch_dir,
            execute_result = execute_result,
        ))

    return ExecutionContext(
        stdout = execute_result.stdout,
        stderr = execute_result.stderr,
        exit_code = execute_result.exit_code,
        output_file_contents = output_file_contents,
    )

def _environment_from_list(system_env: dict[str, str], env: list[str]) -> dict[str, str]:
    result = {}
    for item in env:
        key, value = item.split("=", 1)
        result[key] = value.format(**system_env)
    return result

# Defines a check that runs a command on a set of files and parses the output.
# Also defines a target `command` that the user can override from the provided default.
def check(
        name: str,
        command: str,
        files: list[str],
        tool: str,
        parse: typing.Callable,
        tags: list[str] = [],
        success_codes: list[int] = [],
        error_codes: list[int] = [],
        scratch_dir: bool = False,
        batch_size: int = 64,
        bisect: bool = True,
        update_run_from: None | typing.Callable = None,
        bucket: typing.Callable = bucket_by_workspace,
        read_output_file: None | typing.Callable = None,
        update_command_line_replacements: None | typing.Callable = None,
        maximum_file_size = 1024 * 1024,  # 1 MB
        affects_cache = [],
        timeout_ms = 300000,  # 5 minutes
        cache_results = False,
        cache_ttl_s = 60 * 60 * 24):  # 24 hours
    prefix = native.current_label().prefix()

    def impl(ctx: CheckContext, targets: CheckTargets):
        # Filter files too large
        paths = []
        for file in targets.files:
            if file.size > ctx.inputs().maximum_file_size:
                continue
            paths.append(file.path)

        # Bucket by run from directory
        buckets = bucket(BucketContext(paths = paths))
        for (run_from, targets) in buckets.items():
            batch(ctx, run_from, targets, ctx.inputs().batch_size)

    def batch(ctx: CheckContext, run_from: str, targets: list[str], current_batch_size: int):
        for targets in make_batches(targets, current_batch_size):
            if len(targets) == 1:
                targets_string = targets[0]
            else:
                targets_string = "{first}... ({total} targets)".format(first = targets[0], total = len(targets))
            description = "{prefix} {targets_string}".format(
                prefix = prefix,
                num_files = len(targets),
                targets_string = targets_string,
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

        env = {
            "HOME": ctx.system_env()["HOME"],
            "USER": ctx.system_env()["USER"],
        }
        env.update(tool_environment([ctx.inputs().tool[ToolProvider]]))
        env.update(_environment_from_list(ctx.system_env(), ctx.inputs().environment))

        # Check the cache for the result of the command.
        cache_entry = None
        cached_execution = None
        if ctx.inputs().cache_results and len(targets) == 1:
            cache_entry = _make_cache_entry(ctx.paths(), targets[0], affects_cache, run_from, ctx.inputs().command, env)
            cached_execution = _lookup_cache_entry(cache_entry)

        # Execute the command.
        if cached_execution:
            execution = cached_execution
        else:
            split_command = shlex.split(ctx.inputs().command.format(**replacements))
            execution = _execute_command(split_command, env, run_from, replacements.get("scratch_dir"), ctx.inputs().timeout_ms, read_output_file)

        # Check the exit code of the command.
        error_message = check_exit_code(execution, ctx.inputs().success_codes, ctx.inputs().error_codes)
        if error_message:
            if len(targets) == 1 or not ctx.inputs().bisect:
                fail(error_message + "\n" + pstr(split_command))
            else:
                # If a batch fails, then bisect by a factor of 8.
                bisect_factor = 8
                batch_size = (len(targets) + bisect_factor - 1) // bisect_factor
                batch(ctx, run_from, targets, batch_size)
                return

        # Cache the result of the command.
        if cache_entry and not cached_execution:
            _save_cache_entry(cache_entry, execution, ctx.inputs().cache_ttl_s)

        # Parse the output of the command.
        tarif = parse(ParseContext(
            paths = ctx.paths(),
            run_from = run_from,
            targets = targets,
            scratch_dir = replacements.get("scratch_dir"),
            execution = execution,
        ))
        ctx.add_tarif(json.encode(tarif))

    # Allow the user to override some settings.
    native.int(name = name + "_batch_size", default = batch_size)
    native.bool(name = name + "_bisect", default = bisect)
    native.bool(name = name + "_cache_results", default = cache_results)
    native.int(name = name + "_cache_ttl_s", default = cache_ttl_s)
    native.string(name = name + "_command", default = command)
    native.int_list(name = name + "_error_codes", default = error_codes)
    native.int(name = name + "_maximum_file_size", default = maximum_file_size)
    native.int_list(name = name + "_success_codes", default = success_codes)
    native.int(name = name + "_timeout_ms", default = timeout_ms)
    native.string_list(name = name + "_environment", default = [])

    native.check(
        name = name,
        impl = impl,
        files = files,
        inputs = {
            "batch_size": ":" + name + "_batch_size",
            "bisect": ":" + name + "_bisect",
            "cache_results": ":" + name + "_cache_results",
            "cache_ttl_s": ":" + name + "_cache_ttl_s",
            "command": ":" + name + "_command",
            "error_codes": ":" + name + "_error_codes",
            "maximum_file_size": ":" + name + "_maximum_file_size",
            "success_codes": ":" + name + "_success_codes",
            "timeout_ms": ":" + name + "_timeout_ms",
            "environment": ":" + name + "_environment",
            "tool": tool,
        },
        tags = tags,
    )
