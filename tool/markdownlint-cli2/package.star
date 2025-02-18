load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "markdownlint-cli2",
    runtime = "runtime/node",
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+):(?P<col>\d+) (?P<code>\S+) (?P<message>.+)")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.stderr):
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
    command = "markdownlint-cli2 --json {targets}",
    files = ["file/markdown"],
    tool = ":tool",
    parse = _parse,
    success_codes = [0, 1],
)
