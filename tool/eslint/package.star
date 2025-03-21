load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("rules:read_output_from.star", "read_output_from_scratch_dir")
load("rules:run_from.star", "run_from_parent_containing")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    package = "eslint",
    runtime = "runtime/node",
)

_severity_map = {
    0: tarif.LEVEL_NOTE,
    1: tarif.LEVEL_WARNING,
    2: tarif.LEVEL_ERROR,
}

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    issues = json.decode(ctx.execution.output_file_contents)

    for diagnostic_node in issues:
        file_path = fs.relative_to(diagnostic_node["filePath"], ctx.paths.workspace_dir)

        for message_node in diagnostic_node.get("messages", []):
            regions = []
            if "line" in message_node and "column" in message_node:
                line = message_node["line"]
                column = message_node["column"]
                region = tarif.LocationRegion(
                    start = tarif.Location(
                        line = line,
                        column = column,
                    ),
                    end = tarif.Location(
                        line = message_node.get("endLine", line),
                        column = message_node.get("endColumn", column),
                    ),
                )
                regions.append(region)
                location = region.start
            else:
                location = tarif.Location(
                    line = 0,
                    column = 0,
                )

            rule_id = message_node["ruleId"]
            if not rule_id:
                rule_id = "unknown-rule"

            fixes = []
            if "fix" in message_node:
                fix_node = message_node["fix"]
                fix = tarif.Fix(
                    description = "Fix",
                    edits = [
                        tarif.FileEdit(
                            path = file_path,
                            edit = tarif.TextEdit(
                                region = tarif.OffsetRegion(
                                    start = fix_node["range"][0],
                                    end = fix_node["range"][1],
                                ),
                                text = fix_node["text"],
                            ),
                        ),
                    ],
                )
                fixes.append(fix)

            result = tarif.Result(
                level = _severity_map[message_node["severity"]],
                message = message_node["message"],
                path = file_path,
                rule_id = rule_id,
                location = location,
                regions = regions,
                fixes = fixes,
            )

            results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "eslint --format json --output-file={scratch_dir}/output {targets}",
    files = [
        "file/javascript",
        "file/typescript",
    ],
    tools = [":tool"],
    run_from = run_from_parent_containing([".eslintrc.yaml", "eslint.config.js"]),
    read_output_from = read_output_from_scratch_dir("output"),
    scratch_dir = True,
    parse = _parse,
    success_codes = [0, 1],
)
