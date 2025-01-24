load("rules:check.star", "ParseContext", "UpdateRunFromContext", "check")
load("util:replacements.star", "replacements_from_buffers")
load("util:tarif.star", "tarif")

# Defeines a check that runs a command on a set of files that are expected to modify the files in place.
# Also defines a target `command` that the user can override from the provided default.
def fmt(
        name: str,
        prefix: str,
        command: str,
        files: list[str],
        tool: str,
        verb: str = "Apply formatting",
        message: str = "Unformatted file",
        **kwargs):
    def _update_run_from(ctx: UpdateRunFromContext) -> str:
        # Create a shadow directory with copies all the files we want to format.
        fs.make_shadow(ctx.paths.workspace_dir, ctx.scratch_dir, copies = ctx.targets)
        return ctx.scratch_dir

    def parse(ctx: ParseContext) -> tarif.Tarif:
        results = []
        for file in ctx.targets:
            original_file = fs.join(ctx.paths.workspace_dir, file)
            formatted_file = fs.join(ctx.scratch_dir, file)

            # Generate a set of replacements to transform the original file into the formatted file.
            original = fs.read_file(original_file)
            formatted = fs.read_file(formatted_file)
            replacements = replacements_from_buffers(file, original, formatted)

            if replacements:
                # We have replcements, so generate an issue with a fix.
                fix = tarif.Fix(
                    description = verb,
                    replacements = replacements,
                )
                result = tarif.Result(
                    level = tarif.LEVEL_ERROR,
                    message = message,
                    path = file,
                    rule_id = "format",
                    location = tarif.Location(
                        line = 0,
                        column = 0,
                    ),
                    fixes = [fix],
                )
                results.append(result)
        return tarif.Tarif(prefix = prefix, results = results)

    check(
        name = name,
        command = command,
        files = files,
        tool = tool,
        update_run_from = _update_run_from,
        parse = parse,
        scratch_dir = True,
        **kwargs
    )