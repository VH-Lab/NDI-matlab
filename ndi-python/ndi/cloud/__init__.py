"""
NDI Cloud Integration - Cloud storage and synchronization for NDI.

This package provides integration with the NDI Cloud service for storing,
sharing, and synchronizing neuroscience datasets.
"""

from .api.client import CloudClient
from . import api

__all__ = [
    'CloudClient',
    'api',
]
