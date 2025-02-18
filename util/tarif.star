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

TextEdit = record(
    region = Region,
    text = str,
)

BinaryEdit = record(
    bytes = bytes.Bytes,
)

Edit = TextEdit | BinaryEdit

FileEdit = record(
    path = str,
    edit = Edit,
)

Fix = record(
    description = str,
    edits = list[FileEdit],
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
    results = list[Result],
)

tarif = struct(
    Location = Location,
    Region = Region,
    OffsetRegion = OffsetRegion,
    LocationRegion = LocationRegion,
    TextEdit = TextEdit,
    BinaryEdit = BinaryEdit,
    Edit = Edit,
    FileEdit = FileEdit,
    Fix = Fix,
    Level = Level,
    Result = Result,
    Tarif = Tarif,
    LEVEL_ERROR = Level("error"),
    LEVEL_WARNING = Level("warning"),
    LEVEL_NOTE = Level("note"),
)
