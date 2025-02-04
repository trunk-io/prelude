load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "prisma",
    runtime = "runtime/node",
)

fmt(
    name = "fmt",
    files = ["file/prisma"],
    tool = ":tool",
    command = "prisma format --schema={targets}",
    success_codes = [0],
    batch_size = 1,  # prisma format does not support batch mode
)
