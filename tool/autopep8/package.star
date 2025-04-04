load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "autopep8",
    runtime = "runtime/python",
)

fmt(
    name = "fmt",
    files = ["file/python"],
    tools = [":tool"],
    command = "autopep8 --in-place {targets}",
    success_codes = [0, 2],
)
