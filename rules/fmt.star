load("rules:check.star", "ParseContext", "UpdateRunFromContext", "check")
load("util:tarif.star", "tarif")
load("util:text_edits.star", "text_edits_from_buffers")

def _update_run_from(ctx: UpdateRunFromContext) -> str:
    # Create a shadow directory with copies all the files we want to format.
    fs.make_shadow(ctx.paths.workspace_dir, ctx.scratch_dir, copies = ctx.targets)
    return ctx.scratch_dir

# Defines a check that runs a command on a set of files that are expected to modify the files in place.
# Also defines a target `command` that the user can override from the provided default.
def fmt(
        name: str,
        verb: str = "Apply formatting",
        message: str = "Unformatted file",
        rule_id: str = "format",
        binary: bool = False,
        tags: list[str] = ["fmt"],
        **kwargs):
    def parse(ctx: ParseContext) -> tarif.Tarif:
        results = []
        for file in ctx.targets:
            original_file = fs.join(ctx.paths.workspace_dir, file)
            formatted_file = fs.join(ctx.scratch_dir, file)

            # Generate a set of edits to transform the original file into the formatted file.
            if binary:
                original = fs.read_binary_file(original_file)
                formatted = fs.read_binary_file(formatted_file)
            else:
                original = fs.read_file(original_file)
                formatted = fs.read_file(formatted_file)

            if original == formatted:
                continue

            if binary:
                edit = tarif.FileEdit(
                    path = file,
                    edit = tarif.BinaryEdit(bytes = formatted),
                )
                edits = [edit]
            else:
                edits = text_edits_from_buffers(file, original, formatted)

            if edits:
                # We have replcements, so generate an issue with a fix.
                fix = tarif.Fix(
                    description = verb,
                    edits = edits,
                )
                result = tarif.Result(
                    level = tarif.LEVEL_ERROR,
                    message = message,
                    path = file,
                    rule_id = rule_id,
                    location = tarif.Location(
                        line = 0,
                        column = 0,
                    ),
                    fixes = [fix],
                )
                results.append(result)
        return tarif.Tarif(results = results)

    check(
        name = name,
        update_run_from = _update_run_from,
        parse = parse,
        scratch_dir = True,
        tags = tags,
        **kwargs
    )
