"""Constants for sync operations.

Ported from: ndi.cloud.sync.internal.Constants (MATLAB)
"""

import os


class Constants:
    """Constants for synchronization operations.

    Attributes:
        FILE_SYNC_LOCATION: Temporary relative path (relative to dataset
            folder) to store files portion of NDI documents during sync
    """

    FILE_SYNC_LOCATION = os.path.join('download', 'files')
