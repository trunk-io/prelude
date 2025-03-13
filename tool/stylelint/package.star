load("rules:check.star", "ParseContext", "check")
load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "stylelint",
    runtime = "runtime/node",
)

_severity_map = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "off": tarif.LEVEL_NOTE,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    issues = json.decode(ctx.execution.stderr)
    results = []
    for file in issues:
        source = file["source"]
        for issue in file["warnings"]:
            start_line = issue.get("line", 0)
            start_col = issue.get("column", 0)
            end_line = issue.get("endLine", start_line)
            end_col = issue.get("endColumn", start_col)
            rule_id = issue["rule"]
            description = issue["text"]

            location = tarif.Location(line = start_line, column = start_col)
            region = tarif.LocationRegion(
                start = location,
                end = tarif.Location(line = end_line, column = end_col),
            )

            result = tarif.Result(
                level = tarif.LEVEL_ERROR,
                message = description,
                path = fs.relative_to(source, ctx.paths.workspace_dir),
                rule_id = rule_id,
                location = location,
                regions = [region],
                fixes = [],
            )
            results.append(result)

    return tarif.Tarif(
        results = results,
    )

check(
    name = "check",
    command = "stylelint --formatter=json  {targets}",
    files = [
        "file/css",
        "file/sass",
    ],
    tools = [":tool"],
    parse = _parse,
    success_codes = [0, 2],
)

fmt(
    name = "fix",
    files = [
        "file/css",
        "file/sass",
    ],
    tools = [":tool"],
    verb = "Fix",
    message = "Unfixed file",
    rule_id = "fix",
    command = "stylelint --fix {targets}",
)
