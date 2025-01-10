load("rules:runtime_provider.star", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")

def runtime(
        name: str,
        tool: str,
        install_package: typing.Callable,
        tool_provider: typing.Callable):
    def impl(ctx: CheckContext):
        ctx.emit(RuntimeProvider(
            install_package = install_package,
            tool_provider = tool_provider,
            runtime_dir = ctx.inputs().tool[ToolProvider].directory,
        ))

    native.tool(
        name = name,
        impl = impl,
        inputs = {
            "tool": tool,
        },
    )
