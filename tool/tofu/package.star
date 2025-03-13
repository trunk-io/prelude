load("rules:check.star", "ParseContext", "bucket_by_dir", "check")
load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/opentofu/opentofu/releases/download/v{version}/tofu_{version}_{os}_{cpu}.zip",
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "amd64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{tool_path}",
    },
)

_LEVEL_MAP = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "info": tarif.LEVEL_NOTE,
}

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.stdout)
    results = []
    for issue in issues.get("diagnostics", []):
        range = issue["range"]
        start = range["start"]
        end = range["end"]
        start_line = start["line"]
        start_col = start["column"]
        end_line = end["line"]
        end_col = end["column"]
        filename = range["filename"]
        severity = issue["severity"]
        summary = issue["summary"]
        start_location = tarif.Location(line = start_line, column = start_col)
        end_location = tarif.Location(line = end_line, column = end_col)
        region = tarif.LocationRegion(start = start_location, end = end_location)

        result = tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = summary,
            path = fs.join(ctx.run_from, filename),
            rule_id = "error",
            location = start_location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    files = [
        "file/terraform",
        "file/tfvars",
    ],
    bucket = bucket_by_dir,
    tools = [":tool"],
    parse = _parse,
    command = "tofu validate -json",
    success_codes = [0, 1],
)

fmt(
    name = "fmt",
    files = [
        "file/terraform",
        "file/tfvars",
    ],
    tools = [":tool"],
    command = "tofu fmt -no-color {targets}",
    success_codes = [0],
)
