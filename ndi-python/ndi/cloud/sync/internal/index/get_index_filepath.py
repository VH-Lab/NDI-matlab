"""Get the filepath for the sync index file.

Ported from: ndi.cloud.sync.internal.index.getIndexFilepath (MATLAB)
"""

import os
from typing import Literal


def get_index_filepath(
    ndi_dataset_path: str,
    mode: Literal["read", "write"],
    verbose: bool = True
) -> str:
    """Get the filepath for the sync index file.

    Args:
        ndi_dataset_path: Path to the NDI dataset (must be a folder)
        mode: Whether to get path for reading or writing
        verbose: If True, print verbose output

    Returns:
        Path to the sync index file

    Raises:
        ValueError: If ndi_dataset_path is not a directory
    """
    if not os.path.isdir(ndi_dataset_path):
        raise ValueError(f"ndi_dataset_path must be a folder: {ndi_dataset_path}")

    sync_dir_path = os.path.join(ndi_dataset_path, '.ndi', 'sync')

    if not os.path.isdir(sync_dir_path):
        if mode == "write":
            if verbose:
                print(f'Creating sync directory: {sync_dir_path}')
            os.makedirs(sync_dir_path, exist_ok=True)

    index_path = os.path.join(sync_dir_path, 'index.json')
    return index_path
