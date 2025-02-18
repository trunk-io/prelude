load("rules:check.star", "ParseContext", "check")
load("rules:package_tool.star", "package_tool")
load("util:tarif.star", "tarif")

package_tool(
    name = "tool",
    runtime = "runtime/node",
    package = "markdown-link-check",
)

_RE = regex.Regex(r"\s*\[✖\] (?P<link>.+) → Status: (?P<code>\d+)")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    path = None
    for line in ctx.execution.stdout.splitlines():
        if line.startswith("FILE: "):
            path = line[6:]
            continue
        match = _RE.search(line)
        if match:
            code = match.group("code")
            result = tarif.Result(
                level = tarif.LEVEL_ERROR,
                message = "Dead link found: " + match.group("link") + " (status code: " + code + ")",
                path = path,
                rule_id = "dead-link",
                location = tarif.Location(line = 0, column = 0),
            )
            results.append(result)

    return tarif.Tarif(results = results)

check(
    name = "check",
    files = ["file/markdown"],
    tool = ":tool",
    command = "markdown-link-check {targets}",
    cache_results = True,
    cache_ttl_s = 60 * 60,  # 60 minutes
    batch_size = 1,  # Caching currently does not support batching
    parse = _parse,
    success_codes = [0, 1],
)
