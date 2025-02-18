load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    runtime = "runtime/node",
    package = "sort-package-json",
)

native.file(
    name = "package_json",
    globs = ["**/package.json"],
)

fmt(
    name = "fmt",
    command = "sort-package-json {targets}",
    success_codes = [0],
    files = [
        ":package_json",
    ],
    tool = ":tool",
)
