load("rules:download_tool.star", "download_tool")
load("rules:pass_fail_check.star", "pass_fail_check")

download_tool(
    name = "tool",
    url = "https://github.com/CircleCI-Public/circleci-cli/releases/download/v{version}/circleci-cli_{version}_{os}_{cpu}.tar.gz",
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
        "CIRCLECI_CLI_TELEMETRY_OPTOUT": "true",
    },
    strip_components = 1,
)

pass_fail_check(
    name = "check",
    command = "circleci config validate --skip-update-check {targets}",
    files = ["file/circleci_config"],
    tool = ":tool",
    batch_size = 1,  # Batching not supported
)
