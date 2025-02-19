load("util:batch.star", "make_batches")
load("util:tarif.star", "tarif")
load("util:text_edits.star", "text_edits_from_buffers")

def openai_check(name: str, model: str, prompt: str, description: str, files: list[str]):
    prefix = native.current_label().prefix()

    def check_impl(ctx: CheckContext, result: FilesResult):
        for file in result.files:
            ctx.spawn(description = "{description} ({file})".format(
                description = description,
                file = file,
            )).then(run, ctx, file)

    def run(ctx: CheckContext, file: str, delay = 0):
        time.sleep_ms(count = delay)
        original = fs.read_file(file)
        response = net.post(
            url = "https://api.openai.com/v1/chat/completions",
            headers = {
                "Content-Type": "application/json",
                "Authorization": "Bearer {}".format(ctx.inputs().api_key),
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
                ctx.spawn(description = "{description} ({file}) (retrying after {delay}s)".format(
                    description = description,
                    file = file,
                    delay = delay / 1000.0,
                )).then(run, ctx, file, delay)
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

        replacements = text_edits_from_buffers(file, original, text)

        results = []
        if replacements:
            # We have replcements, so generate an issue with a fix.
            fix = tarif.Fix(
                description = "Update documentation",
                replacements = replacements,
            )
            result = tarif.Result(
                level = tarif.LEVEL_WARNING,
                message = "Automatically updated documentation",
                path = file,
                rule_id = "updated",
                location = tarif.Location(
                    line = 0,
                    column = 0,
                ),
                fixes = [fix],
            )
            results.append(result)

        # Tell the context about the results.
        ctx.add_tarif(json.encode(tarif.Tarif(results = results)))

    native.check(
        name = name,
        description = "Evaluating {}.{}".format(prefix, name),
        impl = check_impl,
        files = files,
        inputs = {
            "api_key": "rules/openai:api_key",
        },
    )
