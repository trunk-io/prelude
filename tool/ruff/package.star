load("rules:check.star", "ParseContext", "check")
load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("util:tarif.star", "tarif")

# Note that Ruff's SARIF output does not include fixes.
def _parse(ctx: ParseContext) -> tarif.Tarif:
    ruff_issues = json.decode(ctx.result.stdout)

    results = []

    for issue in ruff_issues:
        # The absolute path from Ruff; convert to relative
        file_path = fs.relative_to(issue["filename"], ctx.paths.workspace_dir)

        # Extract the start location
        start_row = issue["location"]["row"]
        start_col = issue["location"]["column"]

        # Extract the end location
        end_row = issue["end_location"]["row"]
        end_col = issue["end_location"]["column"]

        # Build a LocationRegion
        region = tarif.LocationRegion(
            start = tarif.Location(line = start_row, column = start_col),
            end   = tarif.Location(line = end_row,   column = end_col),
        )

        # Gather zero or more regions; in this case, just one
        regions = [region]

        # Infer the severity from the code’s first letter
        code = issue["code"]  # e.g. "E402", "F401", etc.
        level = tarif.LEVEL_WARNING

        # Build the list of Fix structs if any fixes are present
        fixes = []
        fix_node = issue.get("fix")
        if fix_node:
            fix_msg = fix_node.get("message", "Fix")
            replacements = []
            for edit in fix_node.get("edits", []):
                # Each edit has a "location" and "end_location"
                edit_start_row = edit["location"]["row"]
                edit_start_col = edit["location"]["column"]
                edit_end_row   = edit["end_location"]["row"]
                edit_end_col   = edit["end_location"]["column"]
                edit_region = tarif.LocationRegion(
                    start = tarif.Location(line = edit_start_row, column = edit_start_col),
                    end   = tarif.Location(line = edit_end_row,   column = edit_end_col),
                )
                text = edit["content"]  # text to replace

                replacements.append(
                    tarif.Replacement(
                        path = file_path,
                        region = edit_region,
                        text = text,
                    )
                )

            # Construct the Fix object
            fix_obj = tarif.Fix(
                description = fix_msg,
                replacements = replacements,
            )
            fixes.append(fix_obj)

        # Construct a single result for this issue
        result = tarif.Result(
            path = file_path,
            location = region.start,  # The primary location is the start line/col
            level = level,
            message = issue.get("message", ""),
            rule_id = code,
            regions = regions,
            fixes = fixes,
        )

        results.append(result)

    # Return the Tarif structure with a chosen prefix
    return tarif.Tarif(prefix = "ruff", results = results)


download_tool(
    name = "tool",
    url = "https://github.com/astral-sh/ruff/releases/download/{version}/ruff-{cpu}-{os}.tar.gz",
    os_map = {
        "windows": "pc-windows",
        "linux": "unknown-linux-musl",
        "macos": "apple-darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    environment = {
        "PATH": "{target_directory}",
    },
    strip_components = 1,
)

check(
    name = "check",
    command = "ruff check --output-format=json --exit-zero {targets}",
    files = ["file/python"],
    tool = ":tool",
    parse = _parse,
    success_codes = [0],
)

fmt(
    name = "fmt",
    command = "ruff format {targets}",
    files = ["file/python"],
    tool = ":tool",
    prefix = "ruff",
    success_codes = [0, 1],
)
