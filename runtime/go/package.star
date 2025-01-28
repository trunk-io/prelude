load("rules:download_tool.star", "download_tool")
load("rules:runtime.star", "runtime")
load("rules:runtime_provider.star", "InstallPackageContext", "RuntimeProvider", "ToolProviderContext")
load("rules:tool_provider.star", "ToolProvider")
load("util:execute.star", "fail_exit_code")

download_tool(
    name = "tool",
    url = "https://golang.org/dl/go{version}.{os}-amd64.tar.gz",
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
        "PATH": "{target_directory}/bin",
    },
    strip_components = 1,
)

def tool_provider(ctx: ToolProviderContext) -> ToolProvider:
    return ToolProvider(
        directory = ctx.directory,
        environment = {
            "PATH": "{}/bin".format(ctx.directory, ctx.runtime_provider.runtime_dir),
        },
    )

def install_package(ctx: InstallPackageContext):
    # Install the package
    result = process.execute(
        command = ["go", "install", "{}@v{}".format(ctx.package, ctx.version)],
        # TODO(chris): What else do we need from https://github.com/trunk-io/plugins/blob/main/runtimes/go/plugin.yaml?
        env = {
            "HOME": ctx.system_env["HOME"],
            "GOROOT": ctx.runtime_provider.runtime_dir,
            "GOPATH": ctx.dest,
            "PATH": "{}/bin".format(ctx.runtime_provider.runtime_dir),
        },
        current_dir = ctx.dest,
    )
    fail_exit_code(result, success_codes = [0])

runtime(
    name = "go",
    tool = ":tool",
    install_package = install_package,
    tool_provider = tool_provider,
)
