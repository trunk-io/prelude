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
    url = "https://github.com/trufflesecurity/trufflehog/releases/download/v{version}/trufflehog_{version}_{os}_{cpu}.tar.gz",
    environment = {
        "PATH": "{tool_path}",
    },
)

def _parse(ctx: ParseContext):
    results = []
    for line in ctx.execution.stdout.splitlines():
        issue = json.decode(line)
        metadata = issue["SourceMetadata"]["Data"]["Filesystem"]
        file = metadata["file"]
        line = metadata["line"]
        detected_type = issue["DetectorName"]
        redacted = issue["Redacted"]
        if redacted == "":
            redacted = "Redacted"

        location = tarif.Location(line = line, column = 0)
        result = tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = "Secret detected: " + redacted,
            path = file,
            rule_id = detected_type,
            location = location,
            regions = [],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    files = ["file/all"],
    tools = [":tool"],
    parse = _parse,
    command = "trufflehog filesystem --json --fail --only-verified --no-update {targets}",
    success_codes = [0, 183],
)
