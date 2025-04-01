load("resource:provider.star", "ResourceProvider")
load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")

def package_tool(
        name: str,
        runtime: str,
        package: str,
        environment: dict[str, str] = {}):
    # Build the configuration for this package installation.
    config = _PackageToolConfig(
        name = name,
        label = native.current_label(),
        package = package,
        environment = environment,
    )

    native.option(name = "version", default = "system")

    native.tool(
        name = name,
        description = "Evaluating {}.{}".format(config.label.prefix(), name),
        impl = lambda ctx: _impl(ctx, config),
        inputs = {
            "runtime": runtime,
            "version": ":version",
            "downloads": "resource/downloads",
        },
    )

_PackageToolConfig = record(
    name = str,
    label = label.Label,
    package = str,
    environment = dict[str, str],
)

def _impl(ctx: CheckContext, config: _PackageToolConfig):
    if ctx.inputs().version == "system":
        ctx.emit(ToolProvider(
            tool_path = "/",
            tool_environment = ctx.system_env(),
        ))
        return
    allocation = resource.Allocation(ctx.inputs().downloads[ResourceProvider].resource, 1)
    ctx.spawn(
        description = "Installing {}.{} v{}".format(config.label.prefix(), config.name, ctx.inputs().version),
        allocations = [allocation],
    ).then(_download, ctx, config)

def _download(ctx: CheckContext, config: _PackageToolConfig):
    # Retrieve the runtime provider from the inputs.
    runtime_provider = ctx.inputs().runtime[RuntimeProvider]
    hasher = blake3.Blake3()
    hasher.update(json.encode([runtime_provider.runtime_path, config.package, ctx.inputs().version]))
    hash = hasher.finalize_hex(length = 16)
    tool_path = "{}/{}/{}".format(ctx.paths().tools_dir, config.label.path(), hash)

    marker = directory_marker.try_lock(tool_path)
    if marker:
        runtime_provider.install_package(InstallPackageContext(
            runtime_provider = runtime_provider,
            system_env = ctx.system_env(),
            tool_name = config.label.path(),
            package = config.package,
            version = ctx.inputs().version,
            dest = tool_path,
        ))
        marker.finalize()

    # Merge the provided environment with the one from the runtime provider.
    tool_environment = {}
    tool_environment.update(config.environment)
    for key, value in runtime_provider.tool_environment.items():
        tool_environment[key] = value.format(
            runtime_path = runtime_provider.runtime_path,
            tool_path = tool_path,
        )
    ctx.emit(ToolProvider(
        tool_path = tool_path,
        tool_environment = tool_environment,
    ))
