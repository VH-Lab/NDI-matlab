"""
NDI DAQ (Data Acquisition) System

Provides abstract interfaces for accessing data from various acquisition systems.
"""

from .system import System
from .reader import Reader
from .metadatareader import MetadataReader
from .daqsystemstring import DAQSystemString

# Import specific hardware readers
from .readers.mfdaq import (
    MFDAQReader,
    Intan,
    Blackrock,
    CEDSpike2,
    SpikeGadgets
)

__all__ = [
    'System',
    'Reader',
    'MetadataReader',
    'DAQSystemString',
    'MFDAQReader',
    'Intan',
    'Blackrock',
    'CEDSpike2',
    'SpikeGadgets',
]
