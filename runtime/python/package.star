load("rules:download_tool.star", "download_tool")
load("rules:runtime.star", "runtime")
load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")
load("util:execute.star", "fail_exit_code")

download_tool(
    name = "tool",
    url = "https://github.com/astral-sh/python-build-standalone/releases/download/20250115/cpython-{version}+20250115-{cpu}-{os}-install_only.tar.gz",
    os_map = {
        "windows": "pc-windows-msvc-shared",
        # We would like to use "unknown-linux-musl", but many binary wheels are missing for this platform.
        # TODO(chris): Select musl and gnu linux separately.
        "linux": "unknown-linux-gnu",
        "macos": "apple-darwin",
    },
    cpu_map = {
        "x86_64": "x86_64",
        "aarch64": "aarch64",
    },
    strip_components = 1,
)

def install_package(ctx: InstallPackageContext):
    # First create the venv
    result = process.execute(
        command = ["python3", "-m", "venv", ctx.dest],
        env = {
            "PATH": "{}/bin:{}".format(ctx.runtime_provider.runtime_path, ctx.system_env["PATH"]),
        },
        current_dir = ctx.dest,
    )
    fail_exit_code(result, success_codes = [0])

    # Now install the package
    result = process.execute(
        command = ["pip", "install", "{}=={}".format(ctx.package, ctx.version)],
        env = {
            "PATH": "{}/bin:{}".format(ctx.dest, ctx.system_env["PATH"]),
        },
        current_dir = ctx.dest,
    )
    fail_exit_code(result, success_codes = [0])

runtime(
    name = "python",
    tool = ":tool",
    install_package = install_package,
    tool_environment = {
        "PATH": "{tool_path}/bin",
        "VIRTUAL_ENV": "{tool_path}",
    },
)
