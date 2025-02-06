load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "svgo",
    runtime = "runtime/node",
)

fmt(
    name = "fmt",
    files = ["file/svg"],
    tool = ":tool",
    command = "svgo --multipass {targets}",
    verb = "Optimize",
    message = "Optimization available",
    rule_id = "unoptimized",
    success_codes = [0],
)
