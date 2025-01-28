def check_exit_code(
        exit_code: int,
        success_codes: list[int] = [],
        error_codes: list[int] = []) -> None | str:
    if len(success_codes) != 0 and len(error_codes) != 0:
        return "success_codes and error_codes are mutually exclusive"
    if len(success_codes) == 0 and len(error_codes) == 0:
        return "success_codes or error_codes are required"
    if exit_code not in success_codes:
        return "exit code '{}' not in success codes '{}'".format(exit_code, success_codes)
    if exit_code in error_codes:
        return "exit code '{}' in error codes '{}'".format(exit_code, error_codes)

def fail_exit_code(
        exit_code: int,
        success_codes: list[int] = [],
        error_codes: list[int] = []):
    error_message = check_exit_code(exit_code, success_codes, error_codes)
    if error_message != None:
        fail(error_message)
