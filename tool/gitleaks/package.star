load("rules:check.star", "ParseContext", "UpdateRunFromContext", "bucket_by_file", "check")
load("rules:download_tool.star", "download_tool")
load("util:tarif.star", "tarif")

download_tool(
    name = "tool",
    url = "https://github.com/gitleaks/gitleaks/releases/download/v{version}/gitleaks_{version}_{os}_{cpu}.tar.gz",
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
)

# Gitleaks doesn't support passing multiple files on the command line, so just link them in a
# sandbox, and run on that directory.
def _update_run_from(ctx: UpdateRunFromContext) -> str:
    for target in ctx.targets:
        shadow_path = fs.join(ctx.scratch_dir, target)
        workspace_path = fs.join(ctx.paths.workspace_dir, target)
        shadow_dir = fs.dirname(shadow_path)
        fs.create_dir_all(shadow_dir)
        fs.link_file(workspace_path, shadow_path)

    return ctx.scratch_dir

def _parse(ctx: ParseContext):
    issues = json.decode(ctx.execution.output_file_contents)

    results = []
    for issue in issues:
        start_line = issue.get("StartLine", 0)
        start_col = issue.get("StartColumn", 0)
        end_line = issue.get("EndLine", start_line)
        end_col = issue.get("EndColumn", start_col)
        rule_id = issue["RuleID"]
        description = issue["Description"]
        file_path = fs.relative_to(issue["File"], ctx.paths.workspace_dir)

        location = tarif.Location(line = start_line, column = start_col)
        region = tarif.LocationRegion(
            start = location,
            end = tarif.Location(line = end_line, column = end_col),
        )

        result = tarif.Result(
            level = tarif.LEVEL_ERROR,
            message = description,
            path = file_path,
            rule_id = rule_id,
            location = location,
            regions = [region],
            fixes = [],
        )
        results.append(result)

    return tarif.Tarif(
        prefix = "gitleaks",
        results = results,
    )

check(
    name = "check",
    scratch_dir = True,
    command = "gitleaks dir --report-format=json --report-path={output_file} --follow-symlinks",
    files = [
        "file/all",
    ],
    tool = ":tool",
    parse = _parse,
    success_codes = [0, 1],
    output_file = True,
    update_run_from = _update_run_from,
    affects_cache = [
        ".gitleaks.toml",
        ".gitleaksignore",
    ],
)
