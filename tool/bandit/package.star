load("rules:check.star", "ParseContext", "bucket_by_file", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "bandit",
    runtime = "runtime/python",
)

_LEVEL_MAP = {
    "LOW": tarif.LEVEL_WARNING,
    "MEDIUM": tarif.LEVEL_ERROR,
    "HIGH": tarif.LEVEL_ERROR,
    "UNDEFINED": tarif.LEVEL_ERROR,
}

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.output_file_contents)
    results = []
    for issue in issues.get("results", []):
        code = issue["code"]
        line_range = issue["line_range"]
        start_line = line_range[0]
        end_line = line_range[-1]
        start_col = issue["col_offset"] + 1
        end_col = issue["end_col_offset"] + 1
        filename = issue["filename"]
        severity = issue["issue_severity"]
        issue_text = issue["issue_text"]
        test_id = issue["test_id"]

        location = tarif.Location(line = start_line, column = start_col)
        region = tarif.LocationRegion(
            start = location,
            end = tarif.Location(line = end_line, column = end_col),
        )

        result = tarif.Result(
            level = _LEVEL_MAP[severity],
            message = issue_text,
            path = filename,
            rule_id = test_id,
            location = location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(
        prefix = "bandit",
        results = results,
    )

check(
    name = "check",
    command = "bandit --exit-zero --ini .bandit --format json --output {output_file} {targets}",
    files = ["file/python"],
    tool = ":tool",
    output_file = True,
    parse = _parse,
    success_codes = [0],
)
