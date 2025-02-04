load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")

# Defines a tool that installs a package for a give runtime.
def package_tool(
        name: str,
        runtime: str,
        package: str,
        environment: dict[str, str] = {}):
    tool_name = native.label_path(":" + name)

    def impl(ctx: CheckContext):
        runtime_provider = ctx.inputs().runtime[RuntimeProvider]
        hasher = blake3.Blake3()
        hasher.update(json.encode([runtime_provider.runtime_path, package, ctx.inputs().version]))
        hash = hasher.finalize_hex(length = 16)
        tool_path = "{}/{}/{}".format(ctx.paths().tools_dir, tool_name, hash)

        marker = directory_marker.try_lock(tool_path)
        if marker:
            runtime_provider.install_package(InstallPackageContext(
                runtime_provider = runtime_provider,
                system_env = ctx.system_env(),
                tool_name = tool_name,
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

    native.string(name = "version")

    native.tool(
        name = name,
        impl = impl,
        inputs = {
            "runtime": runtime,
            "version": ":version",
        },
    )
