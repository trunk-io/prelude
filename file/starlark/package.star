native.file(
    name = "starlark",
    globs = [
        "**/*.star",
        "**/*.bzl",
        "**/BUILD",
        "**/WORKSPACE",
        "**/BUILD.bazel",
        "**/WORKSPACE.bazel",
        "**/MODULE.bazel",
    ],
)
