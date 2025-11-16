"""
NDI Fun - Utility functions for NDI.

This package provides general utility functions including logging,
timestamp generation, channel name parsing, and toolbox checking.
"""

from .name2variablename import name2variableName as name2variablename
from .timestamp import timestamp, timestamp_matlab_format
from .console import console
from .errlog import errlog
from .debuglog import debuglog
from .syslog import syslog
from .find_calc_directories import find_calc_directories
from .check_toolboxes import check_toolboxes, assert_toolbox_installed
from .pseudorandomint import pseudorandomint
from .channelname2prefixnumber import channelname2prefixnumber, prefixnumber2channelname

# Specialized utilities (may have limited functionality - see individual modules)
from .plot_extracellular_spikeshapes import plot_extracellular_spikeshapes
from .stimulustemporalfrequency import stimulustemporalfrequency
from .convertoldnsd2ndi import convertoldnsd2ndi
from .run_platform_checks import run_platform_checks, get_platform_info
from .assertAddonOnPath import assertAddonOnPath, check_addon_available, get_installed_packages

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
    # Specialized utilities
    'plot_extracellular_spikeshapes',
    'stimulustemporalfrequency',
    'convertoldnsd2ndi',
    'run_platform_checks',
    'get_platform_info',
    'assertAddonOnPath',
    'check_addon_available',
    'get_installed_packages',
]
