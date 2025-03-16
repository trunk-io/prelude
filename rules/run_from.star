load("util:fs.star", "walk_up_to_find_dir_of_files")

RunFromContext = record(
    paths = list[str],
)

def run_from_workspace(ctx: RunFromContext) -> dict[str, list[str]]:
    """
    Causes a check to run from the workspace directory.
    """
    return {".": ctx.paths}

def run_from_target(ctx: RunFromContext) -> dict[str, list[str]]:
    """
    Causes a check to run from each of the provided paths.
    """
    directories = {}
    for path in ctx.paths:
        if path == "":
            path = "."
        directories[path] = ["."]
    return directories

def run_from_parent(ctx: RunFromContext) -> dict[str, list[str]]:
    """
    Causes a check to run from the parent directory of each of the provided paths.
    """
    directories = {}
    for path in ctx.paths:
        directory = fs.dirname(path)
        if directory not in directories:
            directories[directory] = []
        directories[directory].append(fs.filename(path))
    return directories

def run_from_parent_containing(files: list[str], ignore_missing = False):
    def inner(ctx: RunFromContext) -> dict[str, list[str]]:
        """
        Causes a check to run from the parent directory of each of the provided paths containing one of the provided files.
        """
        directories = {}
        for path in ctx.paths:
            directory = walk_up_to_find_dir_of_files(path, files) or "."
            if directory == None:
                if ignore_missing:
                    continue
                directory = "."

            if directory not in directories:
                directories[directory] = []
            directories[directory].append(fs.relative_to(path, directory))
        return directories

    return inner
