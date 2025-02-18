load("resource:provider.star", "ResourceProvider")

def impl(ctx: CheckContext):
    ctx.emit(ResourceProvider(resource = resource.Resource(ctx.inputs().max)))

# Allow up to 8GB of memory usage.
# This has no affect unless the user annotates the memory usage for their checks.
native.int(name = "max", default = 8192)

native.tool(
    name = "memory",
    impl = impl,
    inputs = {
        "max": ":max",
    },
)
