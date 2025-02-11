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
    rename_single_file = "osv-scanner",
    environment = {
        "PATH": "{tool_path}",
    },
)

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []

    for result in json.decode(ctx.execution.stdout).get("results", []):
        source_path = result.get("source", {}).get("path", "")
        source_path = fs.relative_to(source_path, ctx.paths.workspace_dir)
        for package_result in result.get("packages", []):
            package_name = package_result.get("package", {}).get("name", "")
            package_version = package_result.get("package", {}).get("version", "")

            for vulnerability in package_result.get("vulnerabilities", []):
                rule_id = vulnerability["id"]
                level = "error"  # TODO(chris): Intodice a "security" level
                message = vulnerability.get("summary", "No summary available")
                affected = vulnerability.get("affected", [])
                range_string = _format_version_ranges(package_name, package_version, affected)

                message = "{package_name} {package_version}: {message}".format(
                    package_name = package_name,
                    package_version = package_version,
                    message = message,
                )
                if range_string:
                    message += " ({range_string})".format(range_string = range_string)

                results.append(
                    tarif.Result(
                        path = source_path,
                        location = tarif.Location(line = 0, column = 0),  # OSV does not provide line/column. Apply to the entire file.
                        level = tarif.Level(level),
                        message = message,
                        rule_id = rule_id,
                    ),
                )

    return tarif.Tarif(results = results)

_zero = semver.parse_version_req("^0.0.0-0")

# Osv-scanner gives us many events for each vulnerability, they may or may not apply to the current
# package or the current version. We need to process these events to determine the range that
# affects both package_name and package_version. This can return None for various reasons, such as
# missing data or invalid semver.
def _format_version_ranges(package_name, package_version, affected) -> str | None:
    package_semver = semver.try_coerce_version(package_version)
    if not package_semver:
        return

    ranges = []
    for affect in affected:
        if affect.get("package", {}).get("name") != package_name:
            continue
        for range in affect.get("ranges", []):
            if range.get("type") == "SEMVER":
                range_string = ""
                is_fixed = True
                last_introduced = None
                first_fixed = None

                # Process all events until we see something > package_semver
                for event in range.get("events", []):
                    introduced = event.get("introduced")
                    if introduced:
                        introduced_semver = semver.try_coerce_version(introduced)
                        if not introduced_semver:
                            # If we can't parse the version, we can't determine the range.
                            return
                        if introduced_semver > package_semver:
                            break
                        else:
                            is_fixed = False
                            last_introduced = introduced_semver

                    fixed = event.get("fixed")
                    if fixed:
                        fixed_semver = semver.try_coerce_version(fixed)
                        if not fixed_semver:
                            # If we can't parse the version, we can't determine the range.
                            return
                        if fixed_semver > package_semver:
                            first_fixed = fixed_semver
                            break
                        else:
                            is_fixed = True

                if is_fixed:
                    continue

                if not first_fixed:
                    if _zero.matches(last_introduced):
                        # Simplified presentation.
                        ranges.append("*")
                    else:
                        ranges.append(">={}".format(last_introduced))
                elif _zero.matches(last_introduced):
                    # Simplified presentation.
                    ranges.append("<{}".format(first_fixed))
                else:
                    ranges.append(">={}, <{}".format(last_introduced, first_fixed))

    if len(ranges) == 0:
        return None

    # I've never seen more than 1 range, but it may be possible according to the spec?
    return "; ".join(set(ranges))

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
    cache_ttl_s = 60 * 60,  # 60 minutes
    affects_cache = ["osv-scanner.toml"],
    batch_size = 1,  # Caching currently does not support batching
    success_codes = [0, 1],
)
