def walk_up_to_find_file(dirname: str, filename: str) -> None | str:
    for i in range(0, 32):
        candidate = "{dirname}/{filename}".format(dirname = dirname, filename = filename)
        if fs.exists(candidate):
            return dirname
        if dirname == "":
            return None
        dirname = fs.dirname(dirname)
