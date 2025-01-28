load("rules:check.star", "ParseContext", "bucket_by_file", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/gitleaks/gitleaks/releases/download/v{version}/gitleaks_{version}_{os}_{cpu}.tar.gz",
    os_map = {
        "windows": "win32",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "x64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{target_directory}",
    },
)

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.output_file_contents)

    results = []
    for issue in issues:
        start_line = issue.get("StartLine", 0)
        start_col = issue.get("StartColumn", 0)
        end_line = issue.get("EndLine", start_line)
        end_col = issue.get("EndColumn", start_col)
        rule_id = issue["RuleID"]
        description = issue["Description"]
        file_path = issue["File"]

        location = tarif.Location(line = start_line, column = start_col)
        region = tarif.LocationRegion(
            start = location,
            end = tarif.Location(line = end_line, column = end_col),
        )

        result = tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = description,
            path = file_path,
            rule_id = rule_id,
            location = location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(
        prefix = "gitleaks",
        results = results,
    )

check(
    name = "check",
    command = "gitleaks dir --report-format=json --report-path={output_file} {targets}",
    files = [
        "file/all",
    ],
    tool = ":tool",
    parse = _parse,
    cache_results = True,
    batch_size = 1,
    success_codes = [0, 1],
    output_file = True,
    affects_cache = [
        ".gitleaks.toml",
        ".gitleaksignore",
    ],
)
