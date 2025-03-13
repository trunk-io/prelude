load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    runtime = "runtime/go",
    package = "mvdan.cc/gofumpt",
)

fmt(
    name = "fmt",
    files = ["file/go"],
    tools = [":tool"],
    command = "gofumpt -w {targets}",
    success_codes = [0],
)
