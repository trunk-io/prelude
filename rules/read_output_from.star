ReadOutputFromContext = record(
    run_from = str,
    targets = list[str],
    scratch_dir = str | None,
    execute_result = process.ExecuteResult,
)

def read_output_from_scratch_dir(file: str):
    """
    Reads the contents of a file from the scratch directory.
    """

    def inner(ctx: ReadOutputFromContext) -> str | None:
        path = fs.join(ctx.scratch_dir, file)
        if not fs.exists(path):
            return None
        return fs.read_file(fs.join(ctx.scratch_dir, file))

    return inner
