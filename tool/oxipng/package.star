load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

download_tool(
    name = "tool",
    url = "https://github.com/shssoichiro/oxipng/releases/download/v{version}/oxipng-{version}-{cpu}-{os}.tar.gz",
    os_map = {
        "windows": "pc-windows-msvc",
        "linux": "unknown-linux-musl",
        "macos": "apple-darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    strip_components = 1,
    environment = {
        "PATH": "{tool_path}",
    },
)

fmt(
    name = "fmt",
    files = ["file/png"],
    tool = ":tool",
    command = "oxipng --strip safe {targets}",
    verb = "Optimize",
    message = "Optimization available",
    rule_id = "unoptimized",
    binary = True,
    success_codes = [0],
)
