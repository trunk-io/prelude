load("util:tarif.star", "tarif")

"""
Generate a set of edits using the word diff between two strings.
"""

def text_edits_from_buffers(path: str, original: str, new: str) -> list[tarif.FileEdit]:
    edits = []
    index = 0

    # Perform a word diff between the two strings. This produces a list of edits less likely
    # to conflict than a line based diff.
    for replacement in diff.word_diff(original, new):
        # For an insertion we are replacing an empty string with the new value.
        replacement = tarif.FileEdit(
            path = path,
            edit = tarif.TextEdit(
                region = tarif.OffsetRegion(
                    start = replacement.old_start,
                    end = replacement.old_end,
                ),
                text = new[replacement.new_start:replacement.new_end],
            ),
        )
        edits.append(replacement)

    return edits
