load("rules:download_tool.star", "download_tool")
load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    package = "github.com/protocolbuffers/txtpbfmt/cmd/txtpbfmt",
    runtime = "runtime/go",
)

fmt(
    name = "fmt",
    files = ["file/textproto"],
    tool = ":tool",
    command = "txtpbfmt {targets}",
    success_codes = [0],
)
