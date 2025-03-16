load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("rules:run_from.star", "run_from_target")
load("rules:target.star", "target_parent_containing")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "cfn-lint",
    runtime = "runtime/python",
)

_LEVEL_MAP = {
    "Error": tarif.LEVEL_ERROR,
    "Warning": tarif.LEVEL_WARNING,
    "Info": tarif.LEVEL_NOTE,
}

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.stdout)

    results = []
    for issue in issues:
        filename = issue["Filename"]
        level = issue["Level"]
        location = issue["Location"]
        start = location["Start"]
        end = location["End"]
        start_line = start["LineNumber"]
        start_col = start["ColumnNumber"]
        end_line = end["LineNumber"]
        end_col = end["ColumnNumber"]
        message = issue["Message"]
        rule = issue["Rule"]
        id = rule["Id"]

        location = tarif.Location(line = start_line, column = start_col)
        region = tarif.LocationRegion(
            start = location,
            end = tarif.Location(line = end_line, column = end_col),
        )

        result = tarif.Result(
            level = _LEVEL_MAP[level],
            message = message,
            path = fs.join(ctx.run_from, filename),
            rule_id = id,
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
    command = "cfn-lint --format=json",
    files = [
        "file/yaml",
        "file/json",
    ],
    target = target_parent_containing([".cfnlintrc", ".cfnlintrc.yaml", ".cfnlintrc.yml"], ignore_missing = True),
    run_from = run_from_target,
    tools = [":tool"],
    parse = _parse,
    error_codes = [32],
)
