_PREFIX = native.current_label().prefix()

def _check_impl(ctx: RuleContext):
    for files in ctx.inputs().files:
        for file in files:
            description = "{prefix}.check {file}".format(prefix = _PREFIX, file = file.path)
            ctx.spawn(description = description).then(_check_file)

def _check_file():
    count = rand.randrange(1000000000, 5000000000)
    time.sleep_ns(count = count)

native.rule(
    name = "check",
    description = "Evaluating {}.check".format(native.current_label().prefix),
    impl = _check_impl,
    tags = ["check"],
    inputs = {
        "files": ["file/all"],
    },
)
