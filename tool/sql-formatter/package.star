load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    runtime = "runtime/node",
    package = "sql-formatter",
)

fmt(
    name = "fmt",
    command = "sql-formatter --fix {targets}",
    success_codes = [0],
    files = ["file/sql"],
    tools = [":tool"],
)
