"""
NDI Time Functions - Time conversion and manipulation utilities.

This package provides utilities for converting between sample indices and times.
"""

from .samples2times import samples2times
from .times2samples import times2samples

__all__ = [
    'samples2times',
    'times2samples',
]
