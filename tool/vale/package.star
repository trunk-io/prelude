load("rules:check.star", "ParseContext", "bucket_by_file", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/errata-ai/vale/releases/download/v{version}/vale_{version}_{os}_{cpu}.tar.gz",
    os_map = {
        "windows": "Windows",
        "linux": "Linux",
        "macos": "macOS",
    },
    cpu_map = {
        "x86_64": "64-bit",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{tool_path}",
    },
)

_LEVEL_MAP = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "suggestion": tarif.LEVEL_NOTE,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []

    # TODO(chris): Validate vale really outputs empty stdout on success
    if ctx.execution.stdout != "":
        map = json.decode(ctx.execution.stdout)

        for file, issues in map.items():
            path = fs.join(ctx.run_from, file)
            for issue in issues:
                check = issue["Check"]
                message = issue["Message"]
                line = issue["Line"]
                span = issue["Span"]
                start_col = span[0]
                end_col = span[1]
                severity = issue["Severity"]

                location = tarif.Location(line = line, column = start_col)
                region = tarif.LocationRegion(
                    start = location,
                    end = tarif.Location(line = line, column = end_col),
                )

                result = tarif.Result(
                    level = _LEVEL_MAP[severity],
                    message = message,
                    path = path,
                    rule_id = check.removeprefix("Vale."),
                    location = location,
                    regions = [region],
                    fixes = [],
                )
                results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    files = [
        "file/markdown",
        "file/html",
        # TODO(chris): Add more file types
    ],
    parse = _parse,
    bucket = bucket_by_file(".vale.ini"),
    tools = [":tool"],
    command = "vale --output=JSON {targets}",
    success_codes = [0, 1, 2],
)
