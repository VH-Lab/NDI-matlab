"""
NDI DAQ Readers - Format-specific data acquisition readers.
"""

# Import MFDAQReader from the mfdaq subpackage
from .mfdaq import MFDAQReader

__all__ = [
    'MFDAQReader',
]
