load("util:batch.star", "make_batches")
load("util:tarif.star", "tarif")

# Defines a check that searches for banned strings in files.
# Also defines a target `strings` that the user can override from the provided default.
def banned_strings_check(
        name: str,
        description: str,
        strings: list[str],
        files: list[str] = ["file/all"]):
    label = native.label_string(":" + name)
    native.string_list(name = "strings", default = strings)

    def impl(ctx: CheckContext, result: FilesResult):
        re = regex.Regex("|".join([regex.escape(word) for word in ctx.inputs().strings]))
        for batch in make_batches(result.files):
            description = "{label} ({num_files} files)".format(label = label, num_files = len(batch))
            ctx.spawn(description = description, weight = len(batch)).then(run, ctx, re, batch)

    def run(ctx: CheckContext, re: regex.Regex, batch: list[str]):
        results = []
        for file in batch:
            abspath = fs.join(ctx.paths().workspace_dir, file)
            data = fs.read_file(abspath)
            line_index = lines.LineIndex(data)
            for match in re.finditer(data):
                line_col = line_index.line_col(match.start(0))
                result = tarif.Result(
                    level = tarif.LEVEL_WARNING,
                    message = "{description}: `{content}'".format(description = description, content = match.group(0)),
                    path = file,
                    rule_id = "found",
                    location = tarif.Location(
                        line = line_col.line + 1,
                        column = line_col.col + 1,
                    ),
                )
                results.append(result)
        res = tarif.Tarif(results = results)
        ctx.add_tarif(json.encode(res))

    native.check(
        name = name,
        impl = impl,
        files = files,
        inputs = {
            "strings": ":strings",
        },
    )
