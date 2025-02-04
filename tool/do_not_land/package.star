load("rules:banned_strings_check.star", "banned_strings_check")

banned_strings_check(
    name = "check",
    description = "Found do not land",
    strings = ["DONOTLAND", "DO-NOT-LAND", "DO_NOT_LAND", "donotland", "do-not-land", "do_not_land"],
)
