def check_exit_code(
        result: process.ExecuteResult,
        success_codes: list[int] = [],
        error_codes: list[int] = []) -> None | str:
    if len(success_codes) != 0 and len(error_codes) != 0:
        return "success_codes and error_codes are mutually exclusive"
    if len(success_codes) == 0 and len(error_codes) == 0:
        return "success_codes or error_codes are required"
    if result.exit_code not in success_codes:
        return "exit code '{}' not in success codes '{}': {}".format(result.exit_code, success_codes, pstr(result))
    if result.exit_code in error_codes:
        return "exit code '{}' in error codes '{}': {}".format(result.exit_code, error_codes, pstr(result))

def fail_exit_code(
        result: process.ExecuteResult,
        success_codes: list[int] = [],
        error_codes: list[int] = []):
    error_message = check_exit_code(result, success_codes, error_codes)
    if error_message != None:
        fail(error_message)
