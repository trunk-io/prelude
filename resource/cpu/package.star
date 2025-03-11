load("resource:provider.star", "eval_resource_provider", "resource_provider")

def impl(ctx: CheckContext):
    ctx.emit(eval_resource_provider(ctx.inputs().max, platform.LOGICAL_CPUS, 100))

# Use up to half the logical cores on the system
native.option(name = "max", default = "{total} / 2")

native.tool(
    name = "cpu",
    description = "Evaluating {}.cpu".format(native.current_label().prefix),
    impl = impl,
    inputs = {
        "max": ":max",
    },
)
