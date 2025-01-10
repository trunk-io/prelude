load("rules:tool_provider.star", "ToolProvider")

UpdateUrlReplacementsContext = record(
    map = dict[str, str],
    paths = Paths,
)

# Defines a tool that downloads and extracts a tool from a URL.
def download_tool(
        name: str,
        url: str,
        strip_components: int = 0,
        rename_single_file: str | None = None,
        os_map: dict[str, str] = {},
        cpu_map: dict[str, str] = {},
        inputs: dict[str, str] = {},
        environment: dict[str, str] = {},
        update_url_replacements: None | typing.Callable = None,
        default_version: str | None = None):
    mangled_label = native.mangled_label(":" + name)

    def impl(ctx: CheckContext):
        replacements = {
            "os": os_map[platform.OS],
            "cpu": cpu_map[platform.ARCH],
            "version": ctx.inputs().version,
        }
        if update_url_replacements:
            update_url_replacements(UpdateUrlReplacementsContext(
                map = replacements,
                paths = ctx.paths(),
            ))

        new_url = url.format(**replacements)

        hasher = blake3.Blake3()
        hasher.update(json.encode([new_url, strip_components, rename_single_file]))
        hash = hasher.finalize_hex(length = 16)
        target_directory = "{}/{}/{}".format(ctx.paths().shared_dir, mangled_label, hash)

        marker = directory_marker.try_lock(target_directory)
        if marker:
            net.download_and_extract(
                url = new_url,
                target = target_directory,
                strip_components = strip_components,
            )
            if rename_single_file:
                files = fs.read_dir(target_directory)
                if len(files) == 1:
                    source = fs.join(target_directory, files[0])
                    dest = fs.join(target_directory, rename_single_file)
                    fs.rename(source, dest)
                    fs.ensure_executable(dest)
                else:
                    fail("Expected a single file in the downloaded archive")

            marker.finalize()

        new_environment = {}
        for key, value in environment.items():
            new_environment[key] = value.format(target_directory = target_directory)

        ctx.emit(ToolProvider(
            directory = target_directory,
            environment = new_environment,
        ))

    if default_version:
        native.string(name = "version", default = default_version)
    else:
        native.string(name = "version")

    native.tool(
        name = name,
        impl = impl,
        inputs = {
            "version": ":version",
        },
    )
