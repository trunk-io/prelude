def exit_code_message(execution) -> str:
    return "stdout:\n{stdout}\nstderr:\n{stderr}".format(
        stdout = execution.stdout,
        stderr = execution.stderr,
    )

def check_exit_code(
        execution,
        success_codes: list[int] = [],
        error_codes: list[int] = []) -> None | str:
    if len(success_codes) != 0 and len(error_codes) != 0:
        return "success_codes and error_codes are mutually exclusive"

    if len(success_codes) != 0 and execution.exit_code not in success_codes:
        return "exit code '{}' not in success codes '{}'\n{}".format(execution.exit_code, success_codes, exit_code_message(execution))
    if len(error_codes) != 0 and execution.exit_code in error_codes:
        return "exit code '{}' in error codes '{}'\n{}".format(execution.exit_code, success_codes, exit_code_message(execution))

def fail_exit_code(
        execution,
        success_codes: list[int] = [],
        error_codes: list[int] = []) -> None:
    error_message = check_exit_code(execution, success_codes, error_codes)
    if error_message != None:
        fail(error_message)
