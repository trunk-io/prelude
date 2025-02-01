load("rules:runtime_provider.star", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")

def runtime(
        name: str,
        tool: str,
        install_package: typing.Callable,
        tool_environment: dict[str, str] = {}):
    def impl(ctx: CheckContext):
        ctx.emit(RuntimeProvider(
            install_package = install_package,
            tool_environment = tool_environment,
            runtime_path = ctx.inputs().tool[ToolProvider].tool_path,
        ))

    native.tool(
        name = name,
        impl = impl,
        inputs = {
            "tool": tool,
        },
    )
