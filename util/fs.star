def walk_up_to_find_file(dirname: str, filename: str) -> None | str:
    for i in range(0, 32):
        candidate = fs.join(dirname, filename)
        if fs.exists(candidate):
            return candidate
        if dirname == "":
            return None
        dirname = fs.dirname(dirname)

def walk_up_to_find_dir_of_file(dirname: str, filename: str) -> None | str:
    for i in range(0, 32):
        candidate = fs.join(dirname, filename)
        if fs.exists(candidate):
            return dirname
        if dirname == "":
            return None
        dirname = fs.dirname(dirname)
