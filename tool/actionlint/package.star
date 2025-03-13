load("rules:check.star", "ParseContext", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "amd64",
        "aarch64": "arm64",
    },
    url = "https://github.com/rhysd/actionlint/releases/download/v{version}/actionlint_{version}_{os}_{cpu}.tar.gz",
    environment = {
        "PATH": "{tool_path}",
    },
)

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.stdout)
    results = []
    for issue in issues:
        col = issue["column"]
        end_col = issue["end_column"]
        file_path = issue["filepath"]
        line = issue["line"]
        message = issue["message"]
        start_location = tarif.Location(line = line, column = col)
        end_location = tarif.Location(line = line, column = end_col)
        region = tarif.LocationRegion(start = start_location, end = end_location)

        result = tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = message,
            path = file_path,
            rule_id = "error",
            location = start_location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    files = ["file/github_workflow"],
    # TODO(chris): Add support for multiple tools as actionlint will shellcheck your workflow
    # files if available.
    tools = [":tool"],
    parse = _parse,
    command = "actionlint -format '{{{{json .}}}}' {targets}",
    success_codes = [0, 1],
)
