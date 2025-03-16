load("resource:provider.star", "ResourceProvider", "resource_provider")
load("rules:package_tool.star", "package_tool")
load("rules:run_from.star", "RunFromContext", "run_from_workspace")
load("rules:target.star", "TargetContext", "target_path")
load("rules:tool_provider.star", "ToolProvider", "tool_environment")
load("util:batch.star", "make_batches")
load("util:execute.star", "check_exit_code")
load("util:fs.star", "walk_up_to_find_dir_of_files", "walk_up_to_find_file")
load("util:tarif.star", "tarif")

# Read from

ReadOutputFromContext = record(
    run_from = str,
    targets = list[str],
    scratch_dir = str | None,
    execute_result = process.ExecuteResult,
)

def read_output_from_scratch_dir(file: str):
    """
    Reads the contents of a file from the scratch directory.
    """

    def inner(ctx: ReadOutputFromContext) -> str | None:
        path = fs.join(ctx.scratch_dir, file)
        if not fs.exists(path):
            return None
        return fs.read_file(fs.join(ctx.scratch_dir, file))

    return inner

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
        output_file_contents = read_output_file(ReadOutputFromContext(
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

def _exit_code_tarif(target: str, message: str, execution: ExecutionContext) -> tarif.Tarif:
    return tarif.Tarif(results = [
        tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = message,
            path = target,
            rule_id = "exit-code",
            location = tarif.Location(
                line = 0,
                column = 0,
            ),
        ),
    ])

# Defines a check that runs a command on a set of files and parses the output.
# Also defines a target `command` that the user can override from the provided default.
def check(
        name: str,
        command: str,
        files: list[str],
        tools: list[str],
        parse: typing.Callable,
        tags: list[str] = [],
        success_codes: list[int] = [],
        error_codes: list[int] = [],
        scratch_dir: bool = False,
        batch_size: int = 64,
        bisect: bool = True,
        target: typing.Callable = target_path,
        run_from: typing.Callable = run_from_workspace,
        update_run_from: None | typing.Callable = None,
        read_output_from: None | typing.Callable = None,
        update_command_line_replacements: None | typing.Callable = None,
        max_file_size = 1024 * 1024,  # 1 MB
        max_concurrency = -1,
        max_memory_usage_mb = -1,
        max_cpu_usage_cores = -1,
        affects_cache = [],
        timeout_ms = 300000,  # 5 minutes
        cache_results = False,
        cache_ttl_s = 60 * 60 * 24):  # 24 hours
    prefix = native.current_label().prefix()

    def impl(ctx: CheckContext, targets: CheckTargets):
        # Filter files too large
        paths = []
        for file in targets.files:
            if file.size > ctx.inputs().max_file_size:
                continue
            paths.append(file.path)

        # Set defaults for resource allocations
        max_concurrency = ctx.inputs().max_concurrency
        memory_usage_mb = ctx.inputs().memory_usage_mb
        cpu_usage_cores = ctx.inputs().cpu_usage_cores
        cpu_provider = ctx.inputs().cpu[ResourceProvider]
        memory_provider = ctx.inputs().memory[ResourceProvider]
        if max_concurrency == -1:
            # If max_concurrency is not set, then use the max concurrency of the CPU provider.
            # We could simply omit this resource instead, but it results in better fairness when
            # each check feeds into the shared cpu queue just a few at a time.
            max_concurrency = cpu_provider.max // cpu_provider.scale
        if memory_usage_mb == -1:
            memory_usage_mb = 0
        if cpu_usage_cores == -1:
            cpu_usage_cores = 100

        # Allocate resources
        allocations = []
        if max_concurrency != 0:
            concurrency = resource.Resource(max_concurrency)
            allocations.append(resource.Allocation(concurrency, 1))
        if memory_usage_mb != 0:
            memory_allocation = resource.Allocation(memory_provider.resource, memory_usage_mb)
            allocations.append(memory_allocation)
        if cpu_usage_cores != 0:
            cpu_allocation = resource.Allocation(cpu_provider.resource, cpu_usage_cores)
            allocations.append(cpu_allocation)

        # Determine the targets
        target_paths = target(TargetContext(paths = paths))

        # Batch the targets according to the their run_from directories
        buckets = run_from(RunFromContext(paths = target_paths))
        for (run_from_dir, targets) in buckets.items():
            batch(ctx, run_from_dir, targets, ctx.inputs().batch_size, allocations)

    def batch(ctx: CheckContext, run_from: str, targets: list[str], current_batch_size: int, allocations: list[resource.Allocation]):
        for targets in make_batches(targets, current_batch_size):
            if len(targets) == 1:
                targets_string = targets[0]
            else:
                targets_string = "{first}... ({total} targets)".format(first = targets[0], total = len(targets))
            description = "{prefix}.{name} {targets_string}".format(
                name = name,
                prefix = prefix,
                num_files = len(targets),
                targets_string = targets_string,
            )
            ctx.spawn(description = description, weight = len(targets), allocations = allocations).then(run, ctx, run_from, targets, allocations)

    def run(ctx: CheckContext, run_from: str, targets: list[str], allocations: list[resource.Allocation]):
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

        tool_providers = [tool[ToolProvider] for tool in ctx.inputs().tools]
        env.update(tool_environment(tool_providers))
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
            execution = _execute_command(split_command, env, run_from, replacements.get("scratch_dir"), ctx.inputs().timeout_ms, read_output_from)

        # Check the exit code of the command.
        error_message = check_exit_code(execution, ctx.inputs().success_codes, ctx.inputs().error_codes)
        if error_message:
            if len(targets) == 1:
                # If a single target fails, then turn the failure into an issue for better presentation and hold the line.
                result = _exit_code_tarif(targets[0], error_message, execution)
                ctx.add_tarif(json.encode(result))
                return
            elif not ctx.inputs().bisect:
                # Without bisection, we can't know which target(s) are causing the failure.
                fail(error_message)
            else:
                # If a batch fails, then bisect by a factor of 8.
                bisect_factor = 8
                batch_size = (len(targets) + bisect_factor - 1) // bisect_factor
                batch(ctx, run_from, targets, batch_size, allocations)
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
    native.option(name = name + "_batch_size", default = batch_size)
    native.option(name = name + "_bisect", default = bisect)
    native.option(name = name + "_cache_results", default = cache_results)
    native.option(name = name + "_cache_ttl_s", default = cache_ttl_s)
    native.option(name = name + "_command", default = command)
    native.option(name = name + "_error_codes", default = error_codes)
    native.option(name = name + "_max_file_size", default = max_file_size)
    native.option(name = name + "_success_codes", default = success_codes)
    native.option(name = name + "_timeout_ms", default = timeout_ms)
    native.option(name = name + "_environment", default = [])
    native.option(name = name + "_memory_usage_mb", default = max_memory_usage_mb)
    native.option(name = name + "_cpu_usage_cores", default = max_cpu_usage_cores)
    native.option(name = name + "_max_concurrency", default = max_concurrency)

    native.check(
        name = name,
        description = "Evaluating {}.{}".format(prefix, name),
        impl = impl,
        files = files,
        inputs = {
            "batch_size": ":" + name + "_batch_size",
            "bisect": ":" + name + "_bisect",
            "cache_results": ":" + name + "_cache_results",
            "cache_ttl_s": ":" + name + "_cache_ttl_s",
            "command": ":" + name + "_command",
            "error_codes": ":" + name + "_error_codes",
            "max_file_size": ":" + name + "_max_file_size",
            "success_codes": ":" + name + "_success_codes",
            "timeout_ms": ":" + name + "_timeout_ms",
            "environment": ":" + name + "_environment",
            "memory_usage_mb": ":" + name + "_memory_usage_mb",
            "cpu_usage_cores": ":" + name + "_cpu_usage_cores",
            "max_concurrency": ":" + name + "_max_concurrency",
            "memory": "resource/memory",
            "cpu": "resource/cpu",
            "tools": tools,
        },
        tags = tags,
    )
