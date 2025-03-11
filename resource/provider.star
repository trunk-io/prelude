ResourceProvider = record(
    resource = resource.Resource,
    max = int,
    scale = int,
)

def resource_provider(max: int, scale: int = 1) -> ResourceProvider:
    return ResourceProvider(resource = resource.Resource(max), max = max, scale = scale)

def eval_resource(value: typing.Any, total: typing.Any, scale: int = 1) -> int:
    if isinstance(value, int):
        return value * scale
    if isinstance(value, float):
        return int(math.ceil(value * scale))
    if isinstance(value, str):
        expr = value.format(total = total)
        return int(math.ceil(math.eval(expr) * scale))

    fail("Expected an int, float, or string, got {}".format(value))

def eval_resource_provider(value: typing.Any, total: typing.Any, scale: int = 1) -> ResourceProvider:
    return resource_provider(eval_resource(value, total, scale), scale)
