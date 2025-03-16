load("rules:check.star", "ParseContext", "check")
load("rules:target.star", "target_parent")
load("rules:run_from.star", "run_from_parent_containing")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/golangci/golangci-lint/releases/download/v{version}/golangci-lint-{version}-{os}-{cpu}.tar.gz",
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
    strip_components = 1,
)

# Note: Not all linters provide a severity level.
LEVEL_MAP = {
    "info": tarif.LEVEL_NOTE,
    "warning": tarif.LEVEL_WARNING,
    "error": tarif.LEVEL_ERROR,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    issues = json.decode(ctx.execution.stdout)
    results = []
    for issue in issues["Issues"]:
        pos = issue["Pos"]
        line = pos["Line"]
        col = pos["Column"]
        filename = pos["Filename"]
        text = issue["Text"]
        code = issue["FromLinter"]
        severity = issue.get("Severity")
        start_location = tarif.Location(line = line, column = col)

        result = tarif.Result(
            level = LEVEL_MAP.get(severity) or tarif.LEVEL_ERROR,
            message = text,
            path = fs.join(ctx.run_from, filename),
            rule_id = code,
            location = start_location,
            regions = [],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "golangci-lint run --sort-results --out-format json --concurrency 1 --exclude gofmt --allow-parallel-runners --issues-exit-code 0 {targets}",
    files = ["file/go"],
    tools = ["runtime/go:tool", ":tool"],
    target = target_parent,
    run_from = run_from_parent_containing(["go.mod"]),
    parse = _parse,
    success_codes = [0, 2, 7],
)
