"""Write the sync index to disk.

Ported from: ndi.cloud.sync.internal.index.writeSyncIndex (MATLAB)
"""

import json
from typing import Dict, Any, TYPE_CHECKING

from ndi.cloud.sync.internal.index.get_index_filepath import get_index_filepath

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def write_sync_index(
    ndi_dataset: 'Dataset',
    sync_index: Dict[str, Any],
    verbose: bool = False
) -> None:
    """Write the sync index to disk.

    Args:
        ndi_dataset: The NDI dataset object
        sync_index: Dictionary containing the sync index data
        verbose: If True, print verbose output
    """
    index_path = get_index_filepath(ndi_dataset.path, "write", verbose=verbose)

    with open(index_path, 'w') as f:
        json.dump(sync_index, f, indent=2)
