load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "yapf",
    runtime = "runtime/python",
)

fmt(
    name = "fmt",
    files = ["file/python"],
    tools = [":tool"],
    command = "yapf --in-place {targets}",
    success_codes = [0],
)
