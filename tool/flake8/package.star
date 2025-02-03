load("rules:check.star", "ParseContext", "bucket_by_file", "check", "read_output_from_scratch_dir")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "flake8",
    runtime = "runtime/python",
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+):(?P<col>\d+): (?P<code>\S+) (?P<message>.+)")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.output_file_contents):
        result = tarif.Result(
            level = tarif.LEVEL_WARNING,
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
    command = "flake8 --output-file={scratch_dir}/output --exit-zero {targets}",
    files = ["file/python"],
    tool = ":tool",
    bucket = bucket_by_file(".flake8"),
    read_output_file = read_output_from_scratch_dir("output"),
    scratch_dir = True,
    parse = _parse,
    success_codes = [0],
)
