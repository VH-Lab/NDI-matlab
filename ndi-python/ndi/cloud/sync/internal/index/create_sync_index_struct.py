"""Create a sync index structure.

Ported from: ndi.cloud.sync.internal.index.createSyncIndexStruct (MATLAB)
"""

from datetime import datetime, timezone
from typing import List, Dict, Any


def create_sync_index_struct(
    local_ndi_ids: List[str],
    remote_ndi_ids: List[str]
) -> Dict[str, Any]:
    """Create the structure for the NDI sync index.

    Creates a structure that can be serialized to JSON for the sync index file.

    Args:
        local_ndi_ids: A list of NDI document UUIDs that are present in the
            local NDI dataset
        remote_ndi_ids: A list of NDI document UUIDs that are present on the
            remote cloud storage

    Returns:
        A dictionary with the following fields:
            - localDocumentIdsLastSync: List of local NDI IDs
            - remoteDocumentIdsLastSync: List of remote NDI IDs
            - lastSyncTimestamp: Current timestamp in ISO 8601 format

    Example:
        >>> local_ids = ["uuid-doc-A", "uuid-doc-B"]
        >>> remote_ids = ["uuid-doc-A", "uuid-doc-C"]
        >>> idx_struct = create_sync_index_struct(local_ids, remote_ids)
        >>> # idx_struct can then be passed to a JSON writing function
    """
    # Create the structure
    index_struct = {
        'localDocumentIdsLastSync': list(local_ndi_ids),
        'remoteDocumentIdsLastSync': list(remote_ndi_ids),
        'lastSyncTimestamp': datetime.now(timezone.utc).isoformat()
    }

    return index_struct
