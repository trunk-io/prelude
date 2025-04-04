load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("rules:read_output_from.star", "read_output_from_scratch_dir")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "djlint",
    runtime = "runtime/python",
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+):(?P<col>\d+): (?P<code>\S+) (?P<message>.+)")

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
                column = int(issue.group("col")),
            ),
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "djlint --quiet --profile=html --linter-output-format='{{filename}}:{{line}}: {{code}} {{message}}' {targets}",
    files = [
        "file/html_template",
    ],
    tools = [":tool"],
    parse = _parse,
    success_codes = [0, 1],
)

# TODO(chris): Add check-* for other kinds of profiles
