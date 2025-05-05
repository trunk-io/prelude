load("resource:provider.star", "eval_resource_provider", "resource_provider")

def impl(ctx: RuleContext):
    ctx.emit(eval_resource_provider(ctx.inputs().max_cores, platform.LOGICAL_CPUS, 100))

# Use up to half the logical cores on the system.
native.option(name = "max_cores", default = "{total} / 2")

native.rule(
    name = "cpu",
    description = "Evaluating {}.cpu".format(native.current_label().prefix),
    impl = impl,
    inputs = {
        "max_cores": ":max_cores",
    },
)
