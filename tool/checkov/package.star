load("rules:check.star", "ParseContext", "UpdateCommandLineReplacementsContext", "bucket_by_file", "check", "read_output_from_scratch_dir")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")
load("util:sarif.star", "parse_sarif_to_tarif_results")

package_tool(
    name = "tool",
    package = "checkov",
    runtime = "runtime/python",
)

def _parse(ctx: ParseContext):
    results = parse_sarif_to_tarif_results(ctx.paths.workspace_dir, ctx.execution.output_file_contents)
    return tarif.Tarif(prefix = "checkov", results = results)

# We need a custom format for the targets, each needs --file=.
def _update_command_line_replacements(ctx: UpdateCommandLineReplacementsContext):
    args = []
    for target in ctx.targets:
        args.append("--file={}".format(target))
    ctx.map["files"] = shlex.join(args)

check(
    name = "check",
    command = "checkov --output-file-path={scratch_dir} --output=sarif --soft-fail {files}",
    files = [
        "file/terraform",
        "file/docker",
        "file/github_workflow",
        # TODO(chris): These exist for cloudformation files. It would be better if we filtered out
        # non-CF files at the file level somehow.
        "file/yaml",
        "file/json"

    ],
    update_command_line_replacements = _update_command_line_replacements,
    tool = ":tool",
    scratch_dir = True,
    read_output_file = read_output_from_scratch_dir("results_sarif.sarif"),
    parse = _parse,
    success_codes = [0],
)

check(
    name = "secrets",
    files = ["file/all"],
    command = "checkov --framework=secrets --enable-secret-scan-all-files --output-file-path={scratch_dir} --output=sarif --soft-fail {files}",
    update_command_line_replacements = _update_command_line_replacements,
    tool = ":tool",
    scratch_dir = True,
    read_output_file = read_output_from_scratch_dir("results_sarif.sarif"),
    parse = _parse,
    success_codes = [0],
)