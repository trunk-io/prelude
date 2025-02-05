load("util:tarif.star", "tarif")

# TODO(chris): This should probably just be done in Rust, no real advantage to doing it in Starlark.

"""
Generate a set of replacements using the word diff between two strings.
"""

def replacements_from_buffers(path: str, original: str, new: str) -> list[tarif.Replacement]:
    replacements = []
    index = 0

    # Perform a word diff between the two strings. This produces a list of replacements less likely
    # to conflict than a line based diff.
    for change in diff.word_diff(original, new):
        if change.tag == diff.INSERT_TAG:
            # For an insertion we are replacing an empty string with the new value.
            replacement = tarif.Replacement(
                path = path,
                region = tarif.OffsetRegion(
                    start = index,
                    end = index,
                ),
                text = change.value,
            )
            replacements.append(replacement)
            # We don't need to increment the index.

        elif change.tag == diff.DELETE_TAG:
            # For a deletion we are replacing the value with an empty string.
            start_index = index
            index += lines.length(change.value)  # Increment by UTF8 codepoints
            replacement = tarif.Replacement(
                path = path,
                region = tarif.OffsetRegion(
                    start = start_index,
                    end = index,
                ),
                text = "",
            )
            replacements.append(replacement)
        elif change.tag == diff.EQUAL_TAG:
            index += lines.length(change.value)  # Increment by UTF8 codepoints

    # TODO(chris): Coalesce replacements that are adjacent. Right now we will produce many deletes
    # followed by an inserts, which can be a single replacement.
    return replacements
