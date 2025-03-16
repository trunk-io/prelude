load("rules:check.star", "ParseContext", "UpdateRunFromContext", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/koalaman/shellcheck/releases/download/v{version}/shellcheck-v{version}.{os}.{cpu}.tar.xz",
    os_map = {
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    environment = {
        "PATH": "{tool_path}",
    },
    strip_components = 1,
)

_LEVEL_MAP = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "style": tarif.LEVEL_WARNING,
    "info": tarif.LEVEL_WARNING,
}

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.stdout)
    results = []
    for issue in issues.get("comments", []):
        start_line = issue["line"]
        start_col = issue["column"]
        end_line = issue["endLine"]
        end_col = issue["endColumn"]
        code = issue["code"]
        message = issue["message"]
        file_path = issue["file"]
        level = issue["level"]

        location = tarif.Location(line = start_line, column = start_col)
        region = tarif.LocationRegion(
            start = location,
            end = tarif.Location(line = end_line, column = end_col),
        )

        result = tarif.Result(
            level = _LEVEL_MAP[level],
            message = message,
            path = file_path,
            rule_id = "SC" + str(code),
            location = location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(
        results = results,
    )

check(
    name = "check",
    command = "shellcheck --format=json1 {targets}",
    files = [
        "file/shell",
    ],
    tools = [":tool"],
    parse = _parse,
    success_codes = [0, 1],
)
