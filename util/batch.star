def make_batches(files: list[typing.Any], max_batch_size: int = 64) -> list[list[typing.Any]]:
    num_files = len(files)
    if num_files == 0:
        return []
    num_batches = (num_files + max_batch_size - 1) // max_batch_size  # Calculate the minimum number of batches needed
    avg_batch_size = num_files // num_batches  # Calculate the average size of each batch
    remainder = num_files % num_batches  # Calculate how many extra files need to be distributed

    batches = []
    start = 0

    for i in range(num_batches):
        # Distribute extra files among the first 'remainder' batches
        end = start + avg_batch_size + (1 if i < remainder else 0)
        batches.append(files[start:end])
        start = end

    return batches
