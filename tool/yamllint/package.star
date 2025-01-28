load("rules:check.star", "ParseContext", "bucket_by_file", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "yamllint",
    runtime = "runtime/python",
)

_RE = regex.Regex(r"(?P<path>.*):(?P<line>\d+):(?P<col>\d+): \[(?P<level>\S+)\] (?P<message>.+) \((?P<code>\S+)\)")

_LEVEL_MAP = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    for issue in _RE.finditer(ctx.execution.stdout):
        result = tarif.Result(
            level = _LEVEL_MAP[issue.group("level")],
            message = issue.group("message"),
            path = issue.group("path"),
            rule_id = issue.group("code"),
            location = tarif.Location(
                line = int(issue.group("line")),
                column = int(issue.group("col")),
            ),
        )
        results.append(result)

    return tarif.Tarif(prefix = "yamllint", results = results)

check(
    name = "check",
    command = "yamllint -f parsable {targets}",
    files = ["file/yaml"],
    tool = ":tool",
    parse = _parse,
    success_codes = [0, 1],
)
