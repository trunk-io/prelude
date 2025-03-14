load("rules:download_tool.star", "download_tool")
load("rules:runtime.star", "runtime")
load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider")
load("rules:tool_provider.star", "ToolProvider")
load("util:execute.star", "fail_exit_code")

download_tool(
    name = "tool",
    url = "https://nodejs.org/dist/v{version}/node-v{version}-{os}-{cpu}.tar.gz",
    os_map = {
        "windows": "windows",
        "linux": "linux",
        "macos": "darwin",
    },
    cpu_map = {
        "x86_64": "x64",
        "aarch64": "arm64",
    },
    strip_components = 1,
)

def install_package(ctx: InstallPackageContext):
    # Install the package
    result = process.execute(
        command = ["npm", "install", "--prefix", ctx.dest, "{}@{}".format(ctx.package, ctx.version)],
        env = {
            "PATH": "{}/bin:{}".format(ctx.runtime_provider.runtime_path, ctx.system_env["PATH"]),
        },
        current_dir = ctx.dest,
    )
    fail_exit_code(result, success_codes = [0])

runtime(
    name = "node",
    tool = ":tool",
    install_package = install_package,
    tool_environment = {
        "PATH": "{tool_path}/node_modules/.bin:{runtime_path}/bin:/usr/bin",
    },
)
