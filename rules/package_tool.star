load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider", "ToolProviderContext")

# Defines a tool that installs a package for a give runtime.
def package_tool(
        name: str,
        runtime: str,
        package: str):
    tool_name = native.mangled_label(":" + name)

    def impl(ctx: CheckContext):
        runtime_provider = ctx.inputs().runtime[RuntimeProvider]
        hasher = blake3.Blake3()
        hasher.update(json.encode([runtime_provider.runtime_dir, package, ctx.inputs().version]))
        hash = hasher.finalize_hex(length = 16)
        dir = "{}/{}/{}".format(ctx.paths().shared_dir, tool_name, hash)

        marker = directory_marker.try_lock(dir)
        if marker:
            runtime_provider.install_package(InstallPackageContext(
                runtime_provider = runtime_provider,
                system_env = ctx.system_env(),
                tool_name = tool_name,
                package = package,
                version = ctx.inputs().version,
                dest = dir,
            ))
            marker.finalize()

        tool_provider = runtime_provider.tool_provider(ToolProviderContext(
            runtime_provider = runtime_provider,
            directory = dir,
        ))
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
