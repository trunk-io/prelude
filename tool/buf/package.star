load("rules:check.star", "ParseContext", "UpdateCommandLineReplacementsContext", "check")
load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    rename_single_file = "buf",
    url = "https://github.com/bufbuild/buf/releases/download/v{version}/buf-{os}-{cpu}",
    os_map = {
        "windows": "Windows",
        "linux": "Linux",
        "macos": "Darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{target_directory}:/usr/bin",
    },
)

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []

    for line in ctx.execution.stdout.splitlines():
        issue = json.decode(line)
        end_col = issue["end_column"]
        end_line = issue["end_line"]
        message = issue["message"]
        path = issue["path"]
        start_col = issue["start_column"]
        start_line = issue["start_line"]
        rule_id = issue["type"]

        location = tarif.Location(line = start_line, column = start_col)
        region = tarif.LocationRegion(
            start = location,
            end = tarif.Location(line = end_line, column = end_col),
        )

        result = tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = message,
            path = path,
            rule_id = rule_id,
            location = location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(prefix = "buf", results = results)

# We need a custom format for the targets, each needs --path=.
def _update_command_line_replacements(ctx: UpdateCommandLineReplacementsContext):
    args = []
    for target in ctx.targets:
        args.append("--path={}".format(target))
    ctx.map["protos"] = shlex.join(args)

# TODO(chris): Add buf-breaking

check(
    name = "check",
    files = ["file/proto"],
    tool = ":tool",
    command = "buf lint --error-format=json {protos}",
    parse = _parse,
    update_command_line_replacements = _update_command_line_replacements,
    success_codes = [0, 100],
)

fmt(
    name = "fmt",
    prefix = "buf",
    files = ["file/proto"],
    tool = ":tool",
    command = "buf format -w {protos}",
    update_command_line_replacements = _update_command_line_replacements,
    success_codes = [0],
)
