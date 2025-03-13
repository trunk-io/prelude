load("rules:check.star", "ParseContext", "check")
load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/dotenv-linter/dotenv-linter/releases/download/v{version}/dotenv-linter-{os}-{cpu}.tar.gz",
    os_map = {
        "windows": "win",
        "linux": "alpine",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{tool_path}",
    },
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+) (?P<code>\S+): (?P<message>.+)")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.stdout):
        result = tarif.Result(
            level = tarif.LEVEL_WARNING,
            message = issue.group("message"),
            path = fs.join(ctx.run_from, issue.group("path")),
            rule_id = issue.group("code"),
            location = tarif.Location(
                line = int(issue.group("line")),
                column = 0,
            ),
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "dotenv-linter --not-check-updates --quiet {targets}",
    files = ["file/env"],
    tools = [":tool"],
    parse = _parse,
    success_codes = [0, 1],
)

fmt(
    name = "fix",
    files = ["file/env"],
    tools = [":tool"],
    command = "dotenv-linter --not-check-updates fix --quiet --no-backup {targets}",
    verb = "Fix",
    message = "Unfixed file",
    rule_id = "fix",
    success_codes = [0],
)
