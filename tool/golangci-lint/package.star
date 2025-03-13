load("rules:check.star", "ParseContext", "bucket_by_blah", "check")
load("rules:download_tool.star", "download_tool")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "github.com/golangci/golangci-lint/cmd/golangci-lint",
    runtime = "runtime/go",
)

# download_tool(
#     name = "tool",
#     url = "https://github.com/golangci/golangci-lint/releases/download/v{version}/golangci-lint-{version}-{os}-{cpu}.tar.gz",
#     os_map = {
#         "windows": "windows",
#         "linux": "linux",
#         "macos": "darwin",
#     },
#     cpu_map = {
#         "x86_64": "amd64",
#         "aarch64": "arm64",
#     },
#     environment = {
#         "PATH": "{tool_path}",
#     },
#     strip_components = 1,
# )

# Note: Not all linters provide a severity level.
LEVEL_MAP = {
    "info": tarif.LEVEL_NOTE,
    "warning": tarif.LEVEL_WARNING,
    "error": tarif.LEVEL_ERROR,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    issues = json.decode(ctx.execution.stdout)
    pprint(issues)
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
            level = LEVEL_MAP.get(severity, tarif.LEVEL_ERROR),
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
    command = "/home/chris/.cache/trunk-cli/tools/prelude/tool/golangci-lint/tool/b056fd7324fc65c03c83d9e770af2607/golangci-lint run --sort-results --out-format json --concurrency 1 --exclude gofmt --allow-parallel-runners --issues-exit-code 0 {targets}",
    files = ["file/go"],
    tools = [":tool"],
    bucket = bucket_by_blah("go.mod"),
    # max_concurrency = 1,
    scratch_dir = True,
    parse = _parse,
    success_codes = [0, 2, 7],
)
