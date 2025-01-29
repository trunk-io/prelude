native.file(
    name = "docker",
    globs = [
        "**/Dockerfile",
        "**/*.Dockerfile",
        "**/Dockerfile.*",
        "**/dockerfile",
        "**/*.dockerfile",
        "**/dockerfile.*",
    ],
)
