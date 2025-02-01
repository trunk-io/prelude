RuntimeProvider = record(
    install_package = typing.Callable,
    tool_environment = dict[str, str],
    runtime_path = str,
)

InstallPackageContext = record(
    runtime_provider = RuntimeProvider,
    system_env = dict[str, str],
    tool_name = str,
    package = str,
    version = str,
    dest = str,
)
