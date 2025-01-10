load("rules:fmt.star", "fmt")

fmt(
    name = "fmt",
    prefix = "rustfmt",
    files = ["file/rust"],
    tool = "tool/rust:tool",
    command = "rustfmt --unstable-features --skip-children {targets}",
    success_codes = [0],
)
