load("rules:check.star", "ParseContext", "check")
load("util:tarif.star", "tarif")

def _parse(ctx: ParseContext) -> tarif.Tarif:
    results = []
    if ctx.execution.exit_code != 0:
        results.append(tarif.Result(
            path = ctx.targets[0],
            level = tarif.LEVEL_ERROR,
            rule_id = "failed",
            location = tarif.Location(line = 0, column = 0),
            message = ctx.execution.stderr,
        ))
    return tarif.Tarif(results = results)

def pass_fail_check(
        name: str,
        **kwargs) -> None:
    check(
        name = name,
        parse = _parse,
        **kwargs
    )
