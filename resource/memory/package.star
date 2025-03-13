load("resource:provider.star", "eval_resource_provider", "resource_provider")

def impl(ctx: CheckContext):
    ctx.emit(eval_resource_provider(ctx.inputs()["max_mb"], platform.MEMORY_BYTES / 1024 / 1000))

# Allow up to half the memory on the system.
# This has no affect unless the user annotates the memory usage for their checks.
native.option(name = "max_mb", default = "{total} / 2")

native.tool(
    name = "memory",
    description = "Evaluating {}.memory".format(native.current_label().prefix),
    impl = impl,
    input = {
        "max_mb": ":max_mb",
    },
)
