load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    runtime = "runtime/go",
    package = "golang.org/x/tools/cmd/goimports",
)

fmt(
    name = "fmt",
    files = ["file/go"],
    tool = ":tool",
    command = "goimports -w {targets}",
    success_codes = [0],
)
