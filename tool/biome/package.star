load("rules:check.star", "ParseContext", "bucket_by_file", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/biomejs/biome/releases/download/cli%2Fv{version}/biome-{os}-{cpu}",
    os_map = {
        "windows": "win32",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "x64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{target_directory}",
    },
    rename_single_file = "biome",
)

_SEVERITY_TO_LEVEL = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "info": tarif.LEVEL_NOTE,
}

# It's non-trivial to turn this into replacements:
# https://github.com/biomejs/biome/blob/0bb86c7bbabebace7ce0f17638f6f58585dae7d6/crates/biome_lsp/src/utils.rs#L26
def _create_replacements_from_diff(line_index, diff_data, file_path):
    dictionary = diff_data["dictionary"]
    ops = diff_data["ops"]

    replacements = []
    offset = 0
    for patch in ops:
        diff_op = patch.get("diffOp")
        if diff_op:
            equal_op = diff_op.get("equal")
            if equal_op:
                start, end = equal_op["range"]
                length = end - start
                offset += length
                continue
            insert_op = diff_op.get("insert")
            if insert_op:
                start, end = insert_op["range"]
                length = end - start
                text_to_insert = dictionary[start:end]
                replacement = tarif.Replacement(
                    path = file_path,
                    region = tarif.OffsetRegion(
                        start = offset,
                        end = offset,
                    ),
                    text = text_to_insert,
                )
                replacements.append(replacement)
                continue

            delete_op = diff_op.get("delete")
            if delete_op:
                start, end = delete_op["range"]
                length = end - start
                replacement = tarif.Replacement(
                    path = file_path,
                    region = tarif.OffsetRegion(
                        start = offset,
                        end = offset + length,
                    ),
                    text = "",
                )
                replacements.append(replacement)
                offset += length
                continue

        equal_lines = patch.get("equalLines")
        if equal_lines:
            current_line = line_index.line_col(offset).line
            line_count = equal_lines["line_count"]
            offset = line_index.offset(current_line + line_count + 1, 0)
            continue

        fail("Unknown diff operation")
    return replacements

def _parse(ctx):
    data = json.decode(ctx.result.stdout)
    results = []

    for diag in data.get("diagnostics", []):
        rule_id = diag.get("category", "unknown-rule")
        severity_str = diag.get("severity", "error")
        level = _SEVERITY_TO_LEVEL[severity_str]
        if rule_id == "format":
            # The description for format errors is not very useful and we want it to match our
            # other formatters.
            message_str = "Unformatted file"
        else:
            message_str = diag.get("description", "No description available")
        loc = diag.get("location", {})
        path_info = loc.get("path", {})
        file_path = path_info["file"]

        regions = []
        source_code = loc["sourceCode"]
        line_index = lines.LineIndex(source_code)
        span = loc.get("span")
        if span:
            start_line_col = line_index.line_col(span[0])
            start_location = tarif.Location(
                line = start_line_col.line + 1,
                column = start_line_col.col + 1,
            )
            end_line_col = line_index.line_col(span[0])
            endt_location = tarif.Location(
                line = end_line_col.line + 1,
                column = end_line_col.col + 1,
            )
            region = tarif.LocationRegion(
                start = tarif.Location(line = 0, column = 0),
                end   = tarif.Location(line = 0, column = 0),
            )
            regions.append(region)
        else:
            start_location = tarif.Location(
                line = 0,
                column = 0,
            )

        fixes = []
        for advice in diag.get("advices", {}).get("advices", []):

            diff = advice.get("diff")
            if diff:
                replacements = _create_replacements_from_diff(line_index, diff, file_path)
                fix = tarif.Fix(
                    # TODO(chris): The advice section sometimes has a deascription of the fix.
                    description = message_str,
                    replacements = replacements,
                )
                fixes.append(fix)

        result = tarif.Result(
            path      = file_path,
            location  = start_location,
            level     = level,
            message   = message_str,
            rule_id   = rule_id,
            regions   = regions,
            fixes     = fixes,
        )

        results.append(result)

    return tarif.Tarif(
        prefix = "biome",
        results = results,
    )

check(
    name = "check",
    command = "biome check --reporter=json {targets}",
    files = [
        "file/javascript",
        "file/typescript",
        "file/json",
    ],
    tool = ":tool",
    parse = _parse,
    success_codes = [0, 1],
)