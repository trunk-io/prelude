load("rules:runtime_provider.star", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")

_RuntimeConfig = record(
    install_package = typing.Callable,
    tool_environment = dict[str, str],
)

def runtime(
        name: str,
        tool: str,
        install_package: typing.Callable,
        tool_environment: dict[str, str] = {}):
    config = _RuntimeConfig(
        install_package = install_package,
        tool_environment = tool_environment,
    )
    native.rule(
        name = name,
        description = "Evaluating {}.{}".format(native.current_label().prefix, name),
        impl = lambda ctx: _impl(ctx, config),
        inputs = {
            "tool": tool,
        },
    )

def _impl(ctx: RuleContext, config: _RuntimeConfig):
    ctx.emit(RuntimeProvider(
        install_package = config.install_package,
        tool_environment = config.tool_environment,
        runtime_path = ctx.inputs().tool[ToolProvider].tool_path,
    ))
