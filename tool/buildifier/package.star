load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")

download_tool(
    name = "tool",
    rename_single_file = "buildifier",
    url = "https://github.com/bazelbuild/buildtools/releases/download/v{version}/buildifier-{os}-{cpu}",
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "amd64",
        "aarch64": "arm64",
    },
    environment = {
        "PATH": "{tool_path}",
    },
)

fmt(
    name = "fmt",
    files = ["file/starlark"],
    tool = ":tool",
    command = "buildifier {targets}",
    success_codes = [0],
)
