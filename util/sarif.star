load("rules:check.star", "ParseContext")
load("util:tarif.star", "tarif")

_LEVEL_MAP = {
    "error": tarif.LEVEL_ERROR,
    "warning": tarif.LEVEL_WARNING,
    "note": tarif.LEVEL_NOTE,
    # Sometimes SARIF uses 'none' or other strings; map them reasonably
    "none": tarif.LEVEL_NOTE,
}

def parse_sarif_to_tarif_results(workspace_dir: str, data: str) -> list[tarif.Result]:
    sarif_data = json.decode(data)
    results = []

    # SARIF top-level object typically has "runs", each run has "results"
    for run in sarif_data.get("runs", []):
        for result_node in run.get("results", []):
            # Extract the SARIF 'level' and convert to tarif.Level
            level_str = result_node.get("level", "note")
            level = _LEVEL_MAP[level_str]

            # Extract message (i.e., diagnostic text)
            message = result_node.get("message", {}).get("text", "")

            # Each result typically references a rule by "ruleId"
            rule_id = result_node.get("ruleId", "unknown-rule")

            # SARIF can contain multiple locations; gather them as regions
            location_nodes = result_node.get("locations", [])
            regions = []

            file_path = ""  # We'll discover the actual file path from the first location
            for i, loc_node in enumerate(location_nodes):
                # We expect "physicalLocation" with an artifactLocation and region
                physical_location = loc_node.get("physicalLocation", {})
                artifact_loc = physical_location.get("artifactLocation", {})
                region_node = physical_location.get("region", {})

                # File path is in artifactLocation["uri"], typically "file:///path/to/file"
                uri = artifact_loc.get("uri", "")

                # Remove leading "file://" if present
                if uri.startswith("file://"):
                    uri = uri[len("file://"):]

                # Convert to a path relative to the workspace
                if uri.startswith("/"):
                    file_path = fs.relative_to(uri, workspace_dir)
                else:
                    file_path = uri

                # Region info
                start_line = region_node.get("startLine", 0)
                start_col = region_node.get("startColumn", 0)
                end_line = region_node.get("endLine", start_line)
                end_col = region_node.get("endColumn", start_col)

                loc_region = tarif.LocationRegion(
                    start = tarif.Location(line = start_line, column = start_col),
                    end = tarif.Location(line = end_line, column = end_col),
                )
                regions.append(loc_region)

            # If we have at least one location, let that define the primary location
            if len(regions) > 0:
                location = regions[0].start
            else:
                location = tarif.Location(line = 0, column = 0)

            # TODO(chris): Parse fixes.
            fixes = []

            # Create the tarif.Result
            result = tarif.Result(
                path = file_path,
                location = location,
                level = level,
                message = message,
                rule_id = rule_id,
                regions = regions,
                fixes = fixes,
            )
            results.append(result)

    return results
