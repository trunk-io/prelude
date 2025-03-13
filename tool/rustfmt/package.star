load("rules:fmt.star", "fmt")

fmt(
    name = "fmt",
    files = ["file/rust"],
    tools = ["tool/rust:tool"],
    command = "rustfmt --unstable-features --skip-children {targets}",
    success_codes = [0],
)
