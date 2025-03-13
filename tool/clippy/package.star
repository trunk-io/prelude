load("rules:check.star", "ParseContext", "UpdateCommandLineReplacementsContext", "bucket_directories_by_file", "check")
load("util:tarif.star", "tarif")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []

    for line in ctx.execution.stdout.splitlines():
        json_obj = json.decode(line)

        result = _parse_line(json_obj)
        if result:
            results.append(result)

    return tarif.Tarif(results = results)

def _parse_line(json_obj) -> None | tarif.Result:
    if json_obj.get("reason") != "compiler-message":
        return None

    main_message = json_obj["message"]
    level = main_message["level"]
    code = main_message["code"]["code"].removeprefix("clippy::") if main_message.get("code") else ""

    primary_span = None
    for span in main_message.get("spans", []):
        if span["is_primary"]:
            primary_span = span
            break

    if primary_span == None:
        return None

    file_name = primary_span["file_name"]

    # TODO(chris): Can we handle results outside of the repository?
    if file_name.startswith("/"):
        return None

    primary_location = tarif.Location(
        line = primary_span["line_start"],
        column = primary_span["column_start"],
    )

    result_region = tarif.LocationRegion(
        start = tarif.Location(
            line = primary_span["line_start"],
            column = primary_span["column_start"],
        ),
        end = tarif.Location(
            line = primary_span["line_end"],
            column = primary_span["column_end"],
        ),
    )

    fixes = []
    for child in main_message.get("children", []):
        if child["level"] == "help" and "spans" in child:
            edits = []
            for span in child["spans"]:
                replacement_text = span.get("suggested_replacement")

                if replacement_text != None:
                    edit = tarif.FileEdit(
                        path = span["file_name"],
                        edit = tarif.TextEdit(
                            region = tarif.OffsetRegion(
                                start = span["byte_start"],
                                end = span["byte_end"],
                            ),
                            text = replacement_text,
                        ),
                    )
                    edits.append(edit)

            if edits:
                fixes.append(tarif.Fix(
                    description = child["message"],
                    edits = edits,
                ))

    return tarif.Result(
        path = file_name,
        location = primary_location,
        level = tarif.Level(level),
        message = main_message["message"],
        rule_id = code,
        regions = [result_region],
        fixes = fixes,
    )

# We need a custom format for the targets, rather than separated by spaces.
def _update_command_line_replacements(ctx: UpdateCommandLineReplacementsContext):
    args = []
    for target in ctx.targets:
        args.append("-p")
        args.append("file://{workspace}/{crate}".format(workspace = ctx.paths.workspace_dir, crate = target))
    ctx.map["crates"] = shlex.join(args)

check(
    name = "check",
    command = "cargo clippy --message-format json --locked --all-targets --all-features {crates}",
    files = ["file/rust"],
    tools = ["tool/rust:tool"],
    parse = _parse,
    success_codes = [0, 1, 101],
    bucket = bucket_directories_by_file("Cargo.toml"),
    update_command_line_replacements = _update_command_line_replacements,
)
