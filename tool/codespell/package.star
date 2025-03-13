load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "codespell",
    runtime = "runtime/python",
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+): (?P<message>.+)")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.stdout):
        result = tarif.Result(
            level = tarif.LEVEL_WARNING,
            message = issue.group("message"),
            path = fs.join(ctx.run_from, issue.group("path")),
            rule_id = "misspelling",
            location = tarif.Location(
                line = int(issue.group("line")),
                column = 0,
            ),
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "codespell {targets}",
    files = ["file/all"],
    tools = [":tool"],
    parse = _parse,
    success_codes = [0, 65],
)
