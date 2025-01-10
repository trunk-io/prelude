Location = record(
    line = int,
    column = int,
)

LocationRegion = record(
    start = Location,
    end = Location,
)

OffsetRegion = record(
    start = int,
    end = int,
)

Region = LocationRegion | OffsetRegion

Replacement = record(
    path = str,
    region = Region,
    text = str,
)

Fix = record(
    description = str,
    replacements = list[Replacement],
)

Level = enum("error", "warning", "note")

Result = record(
    path = str,
    location = Location,
    level = Level,
    message = str,
    rule_id = str,
    regions = field(list[LocationRegion], []),
    fixes = field(list[Fix], []),
)

Tarif = record(
    prefix = str,
    results = list[Result],
)

tarif = struct(
    Location = Location,
    Region = Region,
    OffsetRegion = OffsetRegion,
    LocationRegion = LocationRegion,
    Replacement = Replacement,
    Fix = Fix,
    Level = Level,
    Result = Result,
    Tarif = Tarif,
    LEVEL_ERROR = Level("error"),
    LEVEL_WARNING = Level("warning"),
    LEVEL_NOTE = Level("note"),
)
