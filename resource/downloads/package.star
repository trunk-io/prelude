load("resource:provider.star", "resource_provider")

def impl(ctx: RuleContext):
    ctx.emit(resource_provider(ctx.inputs().max))

native.option(name = "max", default = 8)

native.rule(
    name = "downloads",
    description = "Evaluating {}.downloads".format(native.current_label().prefix),
    impl = impl,
    inputs = {
        "max": ":max",
    },
)
