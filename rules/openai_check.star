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
    prefix = native.current_label().prefix()

    def impl(ctx: CheckContext, targets: CheckTargets):
        for file in targets.files:
            ctx.spawn(description = "{prefix} {file}".format(
                prefix = prefix,
                file = file.path,
            )).then(run, ctx, file)

    def run(ctx: CheckContext, file: FileEntry, delay = 0):
        original = fs.read_file(file.path)
        response = net.post(
            url = "https://api.openai.com/v1/chat/completions",
            headers = {
                "Content-Type": "application/json",
                "Authorization": "Bearer {}".format(ctx.inputs()["api_key"]),
            },
            body = json.encode(
                {
                    "model": model,
                    "messages": [
                        {"role": "user", "content": prompt},
                        {"role": "user", "content": original},
                    ],
                },
            ),
        )

        # Rate limited, try again later.
        if response.status == 429:
            delay_str = response.headers.get("retry-after-ms")
            if delay_str:
                delay = delay_str
                ctx.spawn(description = "{prefix} {file} (retrying after {delay}s)".format(
                    prefix = prefix,
                    file = file.path,
                    delay = delay / 1000.0,
                )).then(wait_and_run, ctx, file, delay)
                return

        if response.status != 200:
            fail("Failed to get response from OpenAI API: " + pstr(response))

        obj = json.decode(response.text)
        text = obj["choices"][0]["message"]["content"]

        # Sometimes the model will wrap the output in markdown, so we need to strip it.
        if text.startswith("```"):
            # Remove the first line, which may also contain the language in addition to ```
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
            # We have replcements, so generate an issue with a fix.
            fix = tarif.Fix(
                description = verb,
                edits = edits,
            )
            result = tarif.Result(
                level = tarif.LEVEL_WARNING,
                message = message,
                path = file.path,
                rule_id = rule_id,
                location = tarif.Location(
                    line = 0,
                    column = 0,
                ),
                fixes = [fix],
            )
            results.append(result)

        # Tell the context about the results.
        ctx.add_tarif(json.encode(tarif.Tarif(results = results)))

    def wait_and_run(ctx: CheckContext, file: str, delay: int):
        time.sleep_ms(count = delay)
        ctx.spawn(description = "{prefix} {file}".format(
            prefix = prefix,
            file = file.path,
        )).then(run, ctx, file)

    native.check(
        name = name,
        description = "Evaluating {}.{}".format(prefix, name),
        impl = impl,
        files = files,
        input = {
            "api_key": "rules/openai:api_key",
        },
    )
