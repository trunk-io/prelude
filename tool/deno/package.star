load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")

download_tool(
    name = "tool",
    rename_single_file = "deno",
    url = "https://github.com/denoland/deno/releases/download/v{version}/deno-{cpu}-{os}.zip",
    os_map = {
        "windows": "pc-windows-msvc",
        "linux": "unknown-linux-gnu",
        "macos": "apple-darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    environment = {
        "PATH": "{tool_path}",
    },
)

fmt(
    name = "fmt",
    files = [
        "file/starlark",
        "file/javascript",
        "file/typescript",
        "file/markdown",
        "file/json",
    ],
    tool = ":tool",
    command = "deno fmt {targets}",
    success_codes = [0, 1],
)
