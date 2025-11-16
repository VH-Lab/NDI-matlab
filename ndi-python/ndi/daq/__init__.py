"""
NDI DAQ (Data Acquisition) System

Provides abstract interfaces for accessing data from various acquisition systems.
"""

from .system import System
from .reader import Reader
from .metadatareader import MetadataReader

# Import specific hardware readers
from .reader.mfdaq import (
    Intan,
    Blackrock,
    CEDSpike2,
    SpikeGadgets
)

__all__ = [
    'System',
    'Reader',
    'MetadataReader',
    'Intan',
    'Blackrock',
    'CEDSpike2',
    'SpikeGadgets',
]
