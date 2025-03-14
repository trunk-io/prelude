load("resource:provider.star", "ResourceProvider")
load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")

# Defines a tool that installs a package for a give runtime.
def package_tool(
        name: str,
        runtime: str,
        package: str,
        environment: dict[str, str] = {}):
    current_label = native.current_label()
    label_path = current_label.relative_to(":" + name).path()
    prefix = current_label.prefix()

    def impl(ctx: CheckContext):
        if ctx.inputs().version == "system":
            ctx.emit(ToolProvider(
                tool_path = "/",
                tool_environment = ctx.system_env(),
            ))
            return
        ctx.spawn(
            description = "Installing {}.{} v{}".format(prefix, name, ctx.inputs().version),
            allocations = [resource.Allocation(ctx.inputs().downloads[ResourceProvider].resource, 1)],
        ).then(download, ctx)

    def download(ctx: CheckContext):
        runtime_provider = ctx.inputs().runtime[RuntimeProvider]
        hasher = blake3.Blake3()
        hasher.update(json.encode([runtime_provider.runtime_path, package, ctx.inputs().version]))
        hash = hasher.finalize_hex(length = 16)
        tool_path = "{}/{}/{}".format(ctx.paths().tools_dir, label_path, hash)

        marker = directory_marker.try_lock(tool_path)
        if marker:
            runtime_provider.install_package(InstallPackageContext(
                runtime_provider = runtime_provider,
                system_env = ctx.system_env(),
                tool_name = label_path,
                package = package,
                version = ctx.inputs().version,
                dest = tool_path,
            ))
            marker.finalize()

        tool_environment = {}
        tool_environment.update(environment)
        for key, value in runtime_provider.tool_environment.items():
            tool_environment[key] = value.format(
                runtime_path = runtime_provider.runtime_path,
                tool_path = tool_path,
            )
        tool_provider = ToolProvider(
            tool_path = tool_path,
            tool_environment = tool_environment,
        )
        ctx.emit(tool_provider)

    native.option(name = "version", default = "system")

    native.tool(
        name = name,
        description = "Evaluating {}.{}".format(prefix, name),
        impl = impl,
        inputs = {
            "runtime": runtime,
            "version": ":version",
            "downloads": "resource/downloads",
        },
    )
