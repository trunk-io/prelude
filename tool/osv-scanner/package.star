load("rules:check.star", "ParseContext", "UpdateCommandLineReplacementsContext", "bucket_by_file", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    os_map = {
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "amd64",
        "arm_64": "arm64",
    },
    url = "https://github.com/google/osv-scanner/releases/download/v{version}/osv-scanner_{os}_{cpu}",
)

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []

    for result in json.decode(ctx.result.stdout).get("results", []):
        source_path = result.get("source", {}).get("path", "")
        source_path = fs.relative_to(source_path, ctx.paths.workspace_dir)
        for package_result in result.get("packages", []):
            package_name = package_result.get("package", {}).get("name", "")
            package_version = package_result.get("package", {}).get("version", "")

            for vulnerability in package_result.get("vulnerabilities", []):
                rule_id = vulnerability["id"]
                level = "error"  # TODO(chris): Intodice a "security" level
                message = vulnerability["summary"]
                range_string = format_version_ranges(vulnerability.get("affected", []))

                results.append(
                    tarif.Result(
                        path = source_path,
                        location = tarif.Location(line = 0, column = 0),  # OSV does not provide line/column. Apply to the entire file.
                        level = tarif.Level(level),
                        message = "{package_name} {package_version}: {message} ({range_string})".format(
                            package_name = package_name,
                            package_version = package_version,
                            message = message,
                            range_string = range_string,
                        ),
                        rule_id = rule_id,
                    ),
                )

    return tarif.Tarif(prefix = "osv-scanner", results = results)

def format_version_ranges(affected):
    result = []
    for affect in affected:
        for range in affect.get("ranges", []):
            if range.get("type") == "SEMVER":
                range_string = ""
                for event in range.get("events", []):
                    introduced = event.get("introduced")
                    if introduced:
                        range_string += ">= {introduced}".format(introduced = introduced)
                    fixed = event.get("fixed")
                    if fixed:
                        range_string += ", < {fixed}".format(fixed = fixed)
                result.append(range_string)
    return "; ".join(result)

# osv-scanner supports batching multiple --lockfile arguments
def _update_command_line_replacements(ctx: UpdateCommandLineReplacementsContext):
    args = []
    for target in ctx.targets:
        args.append("--lockfile")
        args.append(target)
    ctx.map["lockfiles"] = shlex.join(args)

check(
    name = "check",
    command = "osv-scanner {lockfiles} --format json",
    files = ["file/lockfile"],
    tool = ":tool",
    update_command_line_replacements = _update_command_line_replacements,
    parse = _parse,
    cache_results = True,
    cache_ttl = 60 * 30,  # 30 minutes
    batch_size = 1, # Caching currently does not support batching
    success_codes = [0, 1],
)
