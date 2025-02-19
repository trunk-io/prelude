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
    current_label = native.current_label()
    label_path = current_label.relative_to(":" + name).path()
    prefix = current_label.prefix()

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
        tool_path = "{}/{}/{}".format(ctx.paths().tools_dir, label_path, hash)

        marker = directory_marker.try_lock(tool_path)
        if marker:
            net.download_and_extract(
                url = new_url,
                target = tool_path,
                strip_components = strip_components,
            )
            if rename_single_file:
                files = fs.read_dir(tool_path)
                if len(files) == 1:
                    source = fs.join(tool_path, files[0])
                    dest = fs.join(tool_path, rename_single_file)
                    fs.rename(source, dest)
                    fs.ensure_executable(dest)
                else:
                    fail("Expected a single file in the downloaded archive")

            marker.finalize()

        tool_environment = {}
        for key, value in environment.items():
            tool_environment[key] = value.format(tool_path = tool_path)

        ctx.emit(ToolProvider(
            tool_path = tool_path,
            tool_environment = tool_environment,
        ))

    if default_version:
        native.string(name = "version", default = default_version)
    else:
        native.string(name = "version")

    native.tool(
        name = name,
        description = "Downloading {}.{}".format(prefix, name),
        impl = impl,
        inputs = {
            "version": ":version",
        },
    )
