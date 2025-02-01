load("rules:download_tool.star", "UpdateUrlReplacementsContext", "download_tool")
load("rules:tool_provider.star", "ToolProvider")

# Used to support nightly versions and reading the version from rust-toolchain.toml
def _update_url_replacements(ctx: UpdateUrlReplacementsContext):
    if ctx.map["version"] == "rust-toolchain.toml":
        # TODO(chris): Can we have a tool that is different for different files?
        version = toml.decode(fs.read_file(ctx.paths.workspace_dir + "/rust-toolchain.toml"))["toolchain"]["channel"]
    else:
        version = ctx.map["version"]

    if version.startswith("nightly-"):
        ctx.map["rust"] = "{version}/rust-nightly".format(version = version.removeprefix("nightly-"))
    else:
        ctx.map["rust"] = "rust-{version}".format(version = version)

download_tool(
    name = "tool",
    os_map = {
        "windows": "pc-windows-msvc",
        "linux": "unknown-linux-gnu",
        "macos": "apple-darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    url = "https://static.rust-lang.org/dist/{rust}-{cpu}-{os}.tar.gz",
    environment = {
        "PATH": "{tool_path}/bin:/usr/bin",  # TODO(chris): Better way to inherit system PATH
    },
    default_version = "rust-toolchain.toml",
    update_url_replacements = _update_url_replacements,
    strip_components = 2,
)
