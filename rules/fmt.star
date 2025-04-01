load("rules:check.star", "ParseContext", "UpdateRunFromContext", "check")
load("util:tarif.star", "tarif")
load("util:text_edits.star", "text_edits_from_buffers")

def _update_run_from(ctx: UpdateRunFromContext) -> str:
    # Create a shadow directory with copies of all the files we want to format.
    fs.make_shadow(ctx.paths.workspace_dir, ctx.scratch_dir, copies = ctx.targets)
    return ctx.scratch_dir

def fmt(
        name: str,
        verb: str = "Apply formatting",
        message: str = "Unformatted file",
        rule_id: str = "format",
        binary: bool = False,
        tags: list[str] = ["fmt"],
        **kwargs):
    config = _FmtConfig(
        verb = verb,
        message = message,
        rule_id = rule_id,
        binary = binary,
    )
    check(
        name = name,
        update_run_from = _update_run_from,
        parse = lambda ctx: _impl(ctx, config),
        scratch_dir = True,
        tags = tags,
        **kwargs
    )

_FmtConfig = record(
    verb = str,
    message = str,
    rule_id = str,
    binary = bool,
)

def _impl(ctx: ParseContext, config: _FmtConfig) -> tarif.Tarif:
    results = []
    for file in ctx.targets:
        original_file = fs.join(ctx.paths.workspace_dir, file)
        formatted_file = fs.join(ctx.scratch_dir, file)

        # Generate a set of edits to transform the original file into the formatted file.
        if config.binary:
            original = fs.read_binary_file(original_file)
            formatted = fs.read_binary_file(formatted_file)
        else:
            original = fs.read_file(original_file)
            formatted = fs.read_file(formatted_file)

        if original == formatted:
            continue

        if config.binary:
            edit = tarif.FileEdit(
                path = file,
                edit = tarif.BinaryEdit(bytes = formatted),
            )
            edits = [edit]
        else:
            edits = text_edits_from_buffers(file, original, formatted)

        if edits:
            # We have replacements, so generate an issue with a fix.
            fix = tarif.Fix(
                description = config.verb,
                edits = edits,
            )
            result = tarif.Result(
                level = tarif.LEVEL_ERROR,
                message = config.message,
                path = file,
                rule_id = config.rule_id,
                location = tarif.Location(
                    line = 0,
                    column = 0,
                ),
                fixes = [fix],
            )
            results.append(result)
    return tarif.Tarif(results = results)
