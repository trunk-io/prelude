load("resource:provider.star", "resource_provider")

def impl(ctx: CheckContext):
    ctx.emit(resource_provider(ctx.inputs()["max"]))

native.option(name = "max", default = 8)

native.tool(
    name = "downloads",
    description = "Evaluating {}.downloads".format(native.current_label().prefix),
    impl = impl,
    input = {
        "max": ":max",
    },
)
