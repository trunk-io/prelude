load("rules:fmt.star", "fmt")

fmt(
    name = "fmt",
    files = ["file/go"],
    tools = ["runtime/go:tool"],
    command = "gofmt -w {targets}",
    success_codes = [0],
)
