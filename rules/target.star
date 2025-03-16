load("util:fs.star", "walk_up_to_find_dir_of_files")

TargetContext = record(
    paths = list[str],
)

def target_path(ctx: TargetContext) -> list[str]:
    """
    Causes a check to run on each of the provided paths.
    """
    return ctx.paths

def target_workspace(ctx: TargetContext) -> list[str]:
    """
    Causes a check to run on the entire workspace directory.
    """
    return ["."]

def target_parent(ctx: TargetContext) -> list[str]:
    """
    Causes a check to run on the parent directory of each of the provided paths.
    """
    targets = set()
    for target in ctx.paths:
        targets.add(fs.dirname(target))
    return list(targets)

def target_parent_containing(files: list[str], ignore_missing = False):
    """
    Causes a check to run on the parent directory of each of the provided paths, but only if the parent directory contains one of the provided files.
    """

    def inner(ctx: TargetContext) -> list[str]:
        targets = set()
        for target in ctx.paths:
            directory = walk_up_to_find_dir_of_files(target, files)
            if directory == None:
                if ignore_missing:
                    continue
                directory = "."
            targets.add(directory)
        return list(targets)

    return inner
