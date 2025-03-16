load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")

download_tool(
    name = "tool",
    rename_single_file = "taplo",
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    url = "https://github.com/tamasfe/taplo/releases/download/{version}/taplo-{os}-{cpu}.gz",
    environment = {
        "PATH": "{tool_path}",
    },
)

fmt(
    name = "fmt",
    files = ["file/toml"],
    tools = [":tool"],
    command = "taplo format {targets}",
    success_codes = [0],
)
