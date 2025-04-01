load("resource:provider.star", "ResourceProvider")
load("rules:tool_provider.star", "ToolProvider")

UpdateUrlReplacementsContext = record(
    map = dict[str, str],
    paths = Paths,
)

def download_tool(
        name: str,
        url: str,
        strip_components: int = 0,
        rename_single_file: str | None = None,
        os_map: dict[str, str] = {},
        cpu_map: dict[str, str] = {},
        inputs: dict[str, str] = {},
        environment: dict[str, str] = {},
        use_rosetta = False,
        update_url_replacements: None | typing.Callable = None,
        default_version: str | None = None):
    if default_version:
        native.option(name = "version", default = default_version)
    else:
        native.option(name = "version", default = "system")

    config = _DownloadToolConfig(
        name = name,
        label = native.current_label().relative_to(":" + name),
        url = url,
        strip_components = strip_components,
        rename_single_file = rename_single_file,
        os_map = os_map,
        cpu_map = cpu_map,
        environment = environment,
        use_rosetta = use_rosetta,
        update_url_replacements = update_url_replacements,
    )

    native.tool(
        name = name,
        description = "Evaluating {}.{}".format(config.label.prefix(), name),
        impl = lambda ctx: _impl(ctx, config),
        inputs = {
            "version": ":version",
            "downloads": "resource/downloads",
        },
    )

# Configuration record for downloading a tool.
_DownloadToolConfig = record(
    name = str,
    label = label.Label,
    url = str,
    strip_components = int,
    rename_single_file = str | None,
    os_map = dict[str, str],
    cpu_map = dict[str, str],
    environment = dict[str, str],
    use_rosetta = bool,
    update_url_replacements = None | typing.Callable,
)

def _impl(ctx: CheckContext, config: _DownloadToolConfig):
    if ctx.inputs().version == "system":
        ctx.emit(ToolProvider(
            tool_path = "/",
            tool_environment = ctx.system_env(),
        ))
        return
    allocation = resource.Allocation(ctx.inputs().downloads[ResourceProvider].resource, 1)
    ctx.spawn(
        description = "Downloading {}.{} v{}".format(config.label.prefix(), config.name, ctx.inputs().version),
        allocations = [allocation],
    ).then(lambda ctx: _download(ctx, config), ctx)

def _download(ctx: CheckContext, config: _DownloadToolConfig):
    # Build the replacements based on the OS, CPU, and version.
    replacements = {
        "os": config.os_map[platform.OS],
        "cpu": config.cpu_map[platform.ARCH],
        "version": ctx.inputs().version,
    }
    if config.use_rosetta and platform.OS == "macos" and platform.ARCH == "aarch64":
        replacements["cpu"] = "x86_64"

    if config.update_url_replacements:
        config.update_url_replacements(UpdateUrlReplacementsContext(
            map = replacements,
            paths = ctx.paths(),
        ))

    new_url = config.url.format(**replacements)

    hasher = blake3.Blake3()
    hasher.update(json.encode([new_url, config.strip_components, config.rename_single_file]))
    hash = hasher.finalize_hex(length = 16)
    tool_path = "{}/{}/{}".format(ctx.paths().tools_dir, config.label.path(), hash)

    marker = directory_marker.try_lock(tool_path)
    if marker:
        net.download_and_extract(
            url = new_url,
            target = tool_path,
            strip_components = config.strip_components,
        )
        if config.rename_single_file:
            files = fs.read_dir(tool_path)
            if len(files) == 1:
                source = fs.join(tool_path, files[0])
                dest = fs.join(tool_path, config.rename_single_file)
                fs.rename(source, dest)
                fs.ensure_executable(dest)
            else:
                fail("Expected a single file in the downloaded archive")
        marker.finalize()

    tool_environment = {}
    for key, value in config.environment.items():
        tool_environment[key] = value.format(tool_path = tool_path)

    ctx.emit(ToolProvider(
        tool_path = tool_path,
        tool_environment = tool_environment,
    ))
