load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    runtime = "runtime/go",
    package = "mvdan.cc/sh/v3/cmd/shfmt",
)

fmt(
    name = "fmt",
    command = "shfmt -w -s {targets}",
    success_codes = [0],
    files = [
        "file/shell",
    ],
    tools = [":tool"],
)
