load("rules:tool_provider.star", "ToolProvider")

# Tool that provides the system environment.
def _impl(ctx):
    ctx.emit(ToolProvider(
        tool_path = "/",
        tool_environment = ctx.system_env(),
    ))

native.tool(
    name = "system",
    impl = _impl,
)
