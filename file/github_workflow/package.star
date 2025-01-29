native.file(
    name = "github_workflow",
    globs = [
        "**/.github/workflows/*.yml",
        "**/.github/workflows/*.yaml",
    ],
)
