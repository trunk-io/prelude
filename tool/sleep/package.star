_PREFIX = native.current_label().prefix()

def _check_impl(ctx: CheckContext, targets: CheckTargets):
    for file in targets.files:
        description = "{prefix}.check {file}".format(prefix = _PREFIX, file = file.path)
        ctx.spawn(description = description).then(_check_file)

def _check_file():
    count = rand.randrange(1000000000, 5000000000)
    time.sleep_ns(count = count)

native.check(
    name = "check",
    description = "Evaluating {}.check".format(native.current_label().prefix),
    impl = _check_impl,
    files = ["file/all"],
)
