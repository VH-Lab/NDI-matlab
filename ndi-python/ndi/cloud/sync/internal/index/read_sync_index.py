"""Read the sync index from disk.

Ported from: ndi.cloud.sync.internal.index.readSyncIndex (MATLAB)
"""

import json
import os
from typing import Dict, Any, Optional, TYPE_CHECKING

from ndi.cloud.sync.internal.index.get_index_filepath import get_index_filepath

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def read_sync_index(ndi_dataset: 'Dataset', verbose: bool = True) -> Optional[Dict[str, Any]]:
    """Read the sync index from disk.

    Args:
        ndi_dataset: The NDI dataset object
        verbose: If True, print verbose output

    Returns:
        A dictionary containing the sync index data, or None if the index
        file does not exist. The dictionary contains:
            - localDocumentIdsLastSync: List of local document IDs
            - remoteDocumentIdsLastSync: List of remote document IDs
            - lastSyncTimestamp: Timestamp of last sync
    """
    index_path = get_index_filepath(ndi_dataset.path, "read", verbose=verbose)

    if os.path.isfile(index_path):
        with open(index_path, 'r') as f:
            sync_index = json.load(f)
        return sync_index
    else:
        return None
