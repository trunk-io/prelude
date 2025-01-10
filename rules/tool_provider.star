ToolProvider = record(
    directory = str,
    environment = dict[str, str],
)

def tool_environment(tool_providers: list[ToolProvider]) -> dict[str, str]:
    res = {}
    for tool_provider in tool_providers:
        # Merge the environment variables.
        for k, v in tool_provider.environment.items():
            if k in res:
                # TODO(chris): Use operating sysing specific path separator.
                res[k] = res[k] + ":" + v
            else:
                res[k] = v
    return res
