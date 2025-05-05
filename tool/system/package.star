load("rules:tool_provider.star", "ToolProvider")

# Tool that provides the system environment.
def _impl(ctx):
    ctx.emit(ToolProvider(
        tool_path = "/",
        tool_environment = ctx.system_env(),
    ))

native.rule(
    name = "system",
    description = "Evaluating {}.system".format(native.current_label().prefix),
    impl = _impl,
)
