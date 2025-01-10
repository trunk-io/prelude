load("rules:tool_provider.star", "ToolProvider")

RuntimeProvider = record(
    install_package = typing.Callable,
    tool_provider = typing.Callable,
    runtime_dir = str,
)

InstallPackageContext = record(
    runtime_provider = RuntimeProvider,
    system_env = dict[str, str],
    tool_name = str,
    package = str,
    version = str,
    dest = str,
)

ToolProviderContext = record(
    runtime_provider = RuntimeProvider,
    directory = str,
)
