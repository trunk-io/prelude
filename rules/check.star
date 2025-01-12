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

# Execute

ExecuteContext = record(
    command = list[str],
    paths = Paths,
    targets = list[str],
    env = dict[str, str],
    run_from = str,
    timeout_ms = int,
    scratch_dir = str | None,
)

# Default executor that runs a command in the specified directory.
def default_execute(ctx: ExecuteContext):
    return process.execute(
        command = ctx.command,
        env = ctx.env,
        current_dir = ctx.run_from,
        timeout_ms = ctx.timeout_ms,
    )

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
        execute: typing.Callable = default_execute,
        bucket: typing.Callable = bucket_by_workspace,
        update_command_line_replacements: None | typing.Callable = None,
        timeout_ms = 5000,
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

        split_command = shlex.split(command.format(**replacements))

        result = execute(ExecuteContext(
            command = split_command,
            env = tool_environment([ctx.inputs().tool[ToolProvider]]),
            paths = ctx.paths(),
            run_from = run_from,
            targets = targets,
            scratch_dir = replacements.get("scratch_dir"),
            timeout_ms = timeout_ms,
        ))

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
