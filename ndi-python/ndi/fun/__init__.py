"""
NDI Fun - Utility functions for NDI.

This package provides general utility functions including logging,
timestamp generation, channel name parsing, and toolbox checking.
"""

from .name2variablename import name2variablename
from .timestamp import timestamp, timestamp_matlab_format
from .console import console
from .errlog import errlog
from .debuglog import debuglog
from .syslog import syslog
from .find_calc_directories import find_calc_directories
from .check_toolboxes import check_toolboxes, assert_toolbox_installed
from .pseudorandomint import pseudorandomint
from .channelname2prefixnumber import channelname2prefixnumber, prefixnumber2channelname

__all__ = [
    'name2variablename',
    'timestamp',
    'timestamp_matlab_format',
    'console',
    'errlog',
    'debuglog',
    'syslog',
    'find_calc_directories',
    'check_toolboxes',
    'assert_toolbox_installed',
    'pseudorandomint',
    'channelname2prefixnumber',
    'prefixnumber2channelname',
]
