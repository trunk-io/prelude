load("rules:banned_strings_check.star", "banned_strings_check")

banned_strings_check(
    name = "check",
    prefix = "no_curly_quotes",
    description = "Found curly quote",
    strings = ["“", "”", "„", "‟", "‘", "’"],
)
