def _check_impl(ctx: CheckContext, targets: CheckTargets):
    for file in targets.files:
        description = "sleep-check {file}".format(file = file.path)
        ctx.spawn(description = description).then(_check_file)

def _check_file():
    count = rand.randrange(1000000000, 5000000000)
    time.sleep_ns(count = count)

native.check(
    name = "check",
    impl = _check_impl,
    files = ["file/all"],
)
