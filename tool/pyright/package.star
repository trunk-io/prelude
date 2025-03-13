load("rules:check.star", "ParseContext", "bucket_by_file", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    runtime = "runtime/node",
    package = "pyright",
)

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    issues = json.decode(ctx.execution.stdout)
    for issue in issues["generalDiagnostics"]:
        # Pyright uses 0-based line and column numbers and Tarif uses 1-based.
        region = tarif.LocationRegion(
            start = tarif.Location(
                line = issue["range"]["start"]["line"] + 1,
                column = issue["range"]["start"]["character"] + 1,
            ),
            end = tarif.Location(
                line = issue["range"]["end"]["line"] + 1,
                column = issue["range"]["end"]["character"] + 1,
            ),
        )

        path = fs.relative_to(issue["file"], ctx.paths.workspace_dir)
        result = tarif.Result(
            level = tarif.Level(issue["severity"]),
            message = issue["message"],
            path = path,
            rule_id = issue["rule"],
            location = region.start,
            regions = [region],
        )
        results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    command = "pyright --outputjson {targets}",
    bucket = bucket_by_file("pyproject.toml"),
    parse = _parse,
    files = ["file/python"],
    tools = [":tool"],
    success_codes = [0, 1],
)
