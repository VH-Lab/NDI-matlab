"""
NDI DAQ (Data Acquisition) System

Provides abstract interfaces for accessing data from various acquisition systems.
"""

from .system import System
from .reader import Reader
from .metadatareader import MetadataReader

__all__ = [
    'System',
    'Reader',
    'MetadataReader',
]
