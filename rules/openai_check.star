load("util:batch.star", "make_batches")
load("util:tarif.star", "tarif")
load("util:text_edits.star", "text_edits_from_buffers")

def openai_check(
        name: str,
        model: str,
        prompt: str,
        files: list[str],
        verb: str = "Apply updates",
        message: str = "Unupdated file",
        rule_id: str = "update"):
    config = _OpenAICheckConfig(
        label = native.current_label().relative_to(":" + name),
        model = model,
        prompt = prompt,
        verb = verb,
        message = message,
        rule_id = rule_id,
    )
    native.rule(
        name = name,
        description = "Evaluating {}.{}".format(config.label.prefix(), name),
        impl = lambda ctx, targets: _impl(ctx, targets, config),
        tags = ["check"],
        inputs = {
            "api_key": "rules/openai:api_key",
            "files": files,
        },
    )

_OpenAICheckConfig = record(
    label = label.Label,
    model = str,
    prompt = str,
    verb = str,
    message = str,
    rule_id = str,
)

def _impl(ctx: RuleContext, targets: CheckTargets, config: _OpenAICheckConfig):
    for files in ctx.inputs().files:
        for file in files:
            desc = "{prefix} {file}".format(prefix = config.label.prefix(), file = file.path)
            ctx.spawn(description = desc).then(_run, ctx, config, file)

def _run(ctx: RuleContext, config: _OpenAICheckConfig, file: FileEntry, delay: int = 0):
    original = fs.read_file(file.path)
    response = net.post(
        url = "https://api.openai.com/v1/chat/completions",
        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer {}".format(ctx.inputs().api_key),
        },
        body = json.encode({
            "model": config.model,
            "messages": [
                {"role": "user", "content": config.prompt},
                {"role": "user", "content": original},
            ],
        }),
    )

    # Rate limited, try again later.
    if response.status == 429:
        delay_str = response.headers.get("retry-after-ms")
        if delay_str:
            delay = int(delay_str)
            desc = "{prefix} {file} (retrying after {delay}s)".format(
                prefix = config.label.prefix(),
                file = file.path,
                delay = delay / 1000.0,
            )
            ctx.spawn(description = desc).then(_wait_and_run, ctx, config, file, delay)
            return

    if response.status != 200:
        fail("Failed to get response from OpenAI API: " + pstr(response))

    obj = json.decode(response.text)
    text = obj["choices"][0]["message"]["content"]

    # Sometimes the model wraps the output in markdown; strip it.
    if text.startswith("```"):
        text = text[text.find("\n") + 1:]
        if text.endswith("```"):
            text = text[:-3]
        elif text.endswith("```\n"):
            text = text[:-4]
        else:
            fail("Unexpected markdown format: " + text)

    edits = text_edits_from_buffers(file.path, original, text)
    results = []
    if edits:
        fix = tarif.Fix(
            description = config.verb,
            edits = edits,
        )
        result = tarif.Result(
            level = tarif.LEVEL_WARNING,
            message = config.message,
            path = file.path,
            rule_id = config.rule_id,
            location = tarif.Location(
                line = 0,
                column = 0,
            ),
            fixes = [fix],
        )
        results.append(result)

    ctx.add_tarif(json.encode(tarif.Tarif(results = results)))

def _wait_and_run(ctx: RuleContext, config: _OpenAICheckConfig, file: FileEntry, delay: int):
    time.sleep_ms(count = delay)
    desc = "{prefix} {file}".format(prefix = config.label.prefix(), file = file.path)
    ctx.spawn(description = desc).then(_run, ctx, config, file)
