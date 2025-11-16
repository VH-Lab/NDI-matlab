"""
NDI Time Package - Time synchronization and clock management.
"""

from .clocktype import ClockType
from .timemapping import TimeMapping
from .syncrule import SyncRule, FileMatchSyncRule, FileFindSyncRule, CommonTriggersSyncRule
from .syncgraph import SyncGraph
from .timeseries import TimeSeries
from .timereference import TimeReference

# Time conversion utilities
from .fun import samples2times, times2samples

__all__ = [
    'ClockType',
    'TimeMapping',
    'SyncRule',
    'SyncGraph',
    'FileMatchSyncRule',
    'FileFindSyncRule',
    'CommonTriggersSyncRule',
    'TimeSeries',
    'TimeReference',
    'samples2times',
    'times2samples',
]
