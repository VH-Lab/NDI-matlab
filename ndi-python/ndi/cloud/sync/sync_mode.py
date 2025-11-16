"""SyncMode enumeration for dataset synchronization modes.

Ported from: ndi.cloud.sync.enum.SyncMode (MATLAB)
"""

from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.dataset import Dataset
    from ndi.cloud.sync.sync_options import SyncOptions


class SyncMode(Enum):
    """Enumeration of supported dataset synchronization modes.

    Defines modes for unidirectional and bidirectional sync operations
    between a local and a remote (NDI Cloud) dataset, with or without mirroring.

    Attributes:
        DOWNLOAD_NEW: Download documents that are new on the remote dataset
        MIRROR_FROM_REMOTE: Download documents from remote and remove documents
            locally that no longer exist remotely
        UPLOAD_NEW: Upload documents that are new in the local dataset
        MIRROR_TO_REMOTE: Upload documents to remote and remove documents remotely
            that no longer exist locally
        TWO_WAY_SYNC: Two-way sync: copy new/updated documents both ways,
            without removing any documents
    """

    DOWNLOAD_NEW = "downloadNew"
    MIRROR_FROM_REMOTE = "mirrorFromRemote"
    UPLOAD_NEW = "uploadNew"
    MIRROR_TO_REMOTE = "mirrorToRemote"
    TWO_WAY_SYNC = "twoWaySync"

    def execute(self, ndi_dataset: 'Dataset', sync_options: 'SyncOptions') -> None:
        """Execute the sync operation for this mode.

        Args:
            ndi_dataset: The local NDI dataset object
            sync_options: Synchronization options
        """
        # Import here to avoid circular imports
        from ndi.cloud.sync import (
            download_new, mirror_from_remote, upload_new,
            mirror_to_remote, two_way_sync
        )

        # Map enum values to functions
        sync_functions = {
            "downloadNew": download_new,
            "mirrorFromRemote": mirror_from_remote,
            "uploadNew": upload_new,
            "mirrorToRemote": mirror_to_remote,
            "twoWaySync": two_way_sync
        }

        func = sync_functions[self.value]
        func(ndi_dataset, **sync_options.to_dict())
