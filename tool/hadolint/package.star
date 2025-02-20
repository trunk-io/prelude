load("rules:check.star", "ParseContext", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    rename_single_file = "hadolint",
    os_map = {
        "windows": "Windows",
        "linux": "Linux",
        "macos": "Darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "arm64",
    },
    use_rosetta = True,
    url = "https://github.com/hadolint/hadolint/releases/download/v{version}/hadolint-{os}-{cpu}",
    environment = {
        "PATH": "{tool_path}",
    },
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
    for issue in issues:
        line = issue["line"]
        col = issue["column"]
        code = issue["code"]
        message = issue["message"]
        file_path = issue["file"]
        level = issue["level"]

        location = tarif.Location(line = line, column = col)

        result = tarif.Result(
            level = _LEVEL_MAP[level],
            message = message,
            path = file_path,
            rule_id = code,
            location = location,
            regions = [],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(
        results = results,
    )

check(
    name = "check",
    files = ["file/docker"],
    tool = ":tool",
    parse = _parse,
    command = "hadolint -f json --no-fail {targets}",
    success_codes = [0],
)
