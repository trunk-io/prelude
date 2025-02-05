load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "cmake-format",
    runtime = "runtime/python",
)

fmt(
    name = "fmt",
    files = ["file/cmake"],
    tool = ":tool",
    command = "cmake-format -i {targets}",
    success_codes = [0],
)
