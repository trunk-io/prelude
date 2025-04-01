load("util:batch.star", "make_batches")
load("util:tarif.star", "tarif")

def banned_strings_check(
        name: str,
        description: str,
        strings: list[str],
        files: list[str] = ["file/all"]):
    # Register an option to allow the user to override the banned strings.
    native.option(name = "strings", default = strings)

    config = BannedStringsConfig(
        label = native.current_label().relative_to(":" + name),
        description = description,
        strings = strings,
    )
    native.check(
        name = name,
        description = "Evaluating {}.{}".format(native.current_label().prefix(), name),
        impl = lambda ctx, targets: _impl(ctx, targets, config),
        files = files,
        inputs = {
            "strings": ":strings",
        },
    )

BannedStringsConfig = record(
    label = label.Label,
    description = str,
    strings = list[str],
)

def _impl(ctx: CheckContext, targets: CheckTargets, config: BannedStringsConfig):
    # Build a regex from the banned strings provided in the config.
    regex_obj = regex.Regex("|".join([regex.escape(word) for word in config.strings]))
    paths = [file.path for file in targets.files]

    # Batch the file paths and spawn a job for each batch.
    for batch in make_batches(paths):
        batch_description = "{prefix} ({num_files} files)".format(prefix = config.label.prefix(), num_files = len(batch))
        ctx.spawn(description = batch_description, weight = len(batch)).then(
            _run,
            ctx,
            regex_obj,
            batch,
            batch_description,
            config,
        )

def _run(ctx: CheckContext, re_obj: regex.Regex, batch: list[str], batch_description: str, config: BannedStringsConfig):
    results = []
    for file in batch:
        abspath = fs.join(ctx.paths().workspace_dir, file)
        data = fs.try_read_file(abspath)
        if data == None:
            # Skip files that are not UTF-8 encoded.
            continue

        line_index = lines.LineIndex(data)
        for match in re_obj.finditer(data):
            start_line_col = line_index.line_col(match.start(0))
            end_line_col = line_index.line_col(match.end(0))
            start_location = tarif.Location(
                line = start_line_col.line + 1,
                column = start_line_col.col + 1,
            )
            end_location = tarif.Location(
                line = end_line_col.line + 1,
                column = end_line_col.col + 1,
            )
            region = tarif.LocationRegion(
                start = start_location,
                end = end_location,
            )
            result = tarif.Result(
                level = tarif.LEVEL_WARNING,
                message = "{desc}: `{content}'".format(desc = batch_description, content = match.group(0)),
                path = file,
                rule_id = "found",
                location = start_location,
                regions = [region],
            )
            results.append(result)
    res = tarif.Tarif(results = results)
    ctx.add_tarif(json.encode(res))
