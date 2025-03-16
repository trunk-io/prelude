load("rules:check.star", "ParseContext", "check")
load("util:tarif.star", "tarif")

_RE = regex.Regex(r"(?P<path>.*):(?P<line>-?\d+):(?P<message>.*)")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.stdout):
        result = tarif.Result(
            level = tarif.LEVEL_WARNING,
            message = issue.group("message"),
            path = issue.group("path"),
            rule_id = "error",
            location = tarif.Location(
                line = int(issue.group("line")),
                column = 0,
            ),
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "git diff --check {targets}",
    files = ["file/all"],
    tools = ["tool/system"],
    parse = _parse,
    success_codes = [0, 1, 2],
)
