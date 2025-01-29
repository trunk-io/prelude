load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "black",
    runtime = "runtime/python",
)

fmt(
    name = "fmt",
    prefix = "black",
    files = ["file/python"],
    tool = ":tool",
    command = "black -q {targets}",
    success_codes = [0],
)
