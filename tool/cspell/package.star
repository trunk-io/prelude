load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "cspell",
    runtime = "runtime/node",
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+):(?P<col>\d+) - (?P<message>.+)")

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
                column = int(issue.group("col")),
            ),
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "cspell lint --no-progress --no-summary --show-suggestions --no-cache {targets}",
    files = ["file/all"],
    tools = [":tool"],
    parse = _parse,
    success_codes = [0, 1],
)
