load("rules:fmt.star", "fmt")

fmt(
    name = "fmt",
    files = ["file/go"],
    tool = "runtime/go:tool",
    command = "gofmt -w {targets}",
    success_codes = [0],
)
