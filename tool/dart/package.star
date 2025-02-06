load("rules:check.star", "ParseContext", "check")
load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://storage.googleapis.com/dart-archive/channels/stable/release/{version}/sdk/dartsdk-{os}-{cpu}-release.zip",
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "macos",
    },
    cpu_map = {
        "x86_64": "x64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{tool_path}/bin",
    },
    strip_components = 1,
)

_RE = regex.Regex(r"\s*(?P<severity>\S+) - (?P<path>.*):(?P<line>\d+):(?P<col>\d+) - (?P<message>.+) - (?P<code>\S+)")

_LEVEL_MAP = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "info": tarif.LEVEL_WARNING,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.stdout):
        result = tarif.Result(
            level = _LEVEL_MAP[issue.group("severity")],
            message = issue.group("message"),
            path = fs.join(ctx.run_from, issue.group("path")),
            rule_id = issue.group("code"),
            location = tarif.Location(
                line = int(issue.group("line")),
                column = int(issue.group("col")),
            ),
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "dart analyze {targets}",
    files = ["file/dart"],
    tool = ":tool",
    parse = _parse,
    success_codes = [0, 3],
)

fmt(
    name = "fix",
    files = ["file/dart"],
    tool = ":tool",
    command = "dart fix --apply {targets}",
    verb = "Apply fixes",
    message = "Fixes available",
    rule_id = "unfixed",
    success_codes = [0],
)

fmt(
    name = "fmt",
    files = ["file/dart"],
    tool = ":tool",
    command = "dart format {targets}",
    success_codes = [0],
)
