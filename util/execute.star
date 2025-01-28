def check_exit_code(
        execution,
        success_codes: list[int] = [],
        error_codes: list[int] = []) -> None | str:
    if len(success_codes) != 0 and len(error_codes) != 0:
        return "success_codes and error_codes are mutually exclusive"
    if len(success_codes) == 0 and len(error_codes) == 0:
        return "success_codes or error_codes are required"
    if execution.exit_code not in success_codes:
        return "exit code '{}' not in success codes '{}':\n{}".format(execution.exit_code, success_codes, execution)
    if execution.exit_code in error_codes:
        return "exit code '{}' in error codes '{}':\n{}".format(execution.exit_code, error_codes, execution)

def fail_exit_code(
        execution,
        success_codes: list[int] = [],
        error_codes: list[int] = []) -> None:
    error_message = check_exit_code(execution, success_codes, error_codes)
    if error_message != None:
        fail(error_message)
