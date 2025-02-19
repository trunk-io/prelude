load("resource:provider.star", "ResourceProvider")

def impl(ctx: CheckContext):
    ctx.emit(ResourceProvider(resource = resource.Resource(ctx.inputs().max)))

native.int(name = "max", default = 8)

native.tool(
    name = "downloads",
    description = "Evaluating {}.downloads".format(native.current_label().prefix),
    impl = impl,
    inputs = {
        "max": ":max",
    },
)
