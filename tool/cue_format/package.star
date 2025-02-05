load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "cuelang.org/go/cmd/cue",
    runtime = "runtime/go",
)

fmt(
    name = "fmt",
    files = ["file/cue"],
    tool = ":tool",
    command = "cue fmt {targets}",
    success_codes = [0],
)
