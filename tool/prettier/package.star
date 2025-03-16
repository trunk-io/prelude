load("rules:fmt.star", "fmt")
load("rules:package_tool.star", "package_tool")

package_tool(
    name = "tool",
    runtime = "runtime/node",
    package = "prettier",
)

native.file(
    name = "configs",
    globs = ["**/.prettierrc", "**/.stylelintrc"],
)

fmt(
    name = "fmt",
    command = "prettier -w {targets}",
    success_codes = [0],
    files = [
        ":configs",
        "file/css",
        "file/graphql",
        "file/html",
        "file/javascript",
        "file/json",
        "file/markdown",
        "file/postcss",
        "file/sass",
        "file/typescript",
        "file/yaml",
    ],
    tools = [":tool"],
)
