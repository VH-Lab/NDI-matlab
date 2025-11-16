"""Sync index management for cloud synchronization.

This module provides functions for reading, writing, and managing the
synchronization index that tracks the state of local and remote datasets.

Ported from: ndi.cloud.sync.internal.index (MATLAB)
"""

from ndi.cloud.sync.internal.index.get_index_filepath import get_index_filepath
from ndi.cloud.sync.internal.index.read_sync_index import read_sync_index
from ndi.cloud.sync.internal.index.write_sync_index import write_sync_index
from ndi.cloud.sync.internal.index.create_sync_index_struct import create_sync_index_struct
from ndi.cloud.sync.internal.index.update_sync_index import update_sync_index

__all__ = [
    'get_index_filepath',
    'read_sync_index',
    'write_sync_index',
    'create_sync_index_struct',
    'update_sync_index',
]
