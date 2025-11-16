"""
NDI - Neuroscience Data Interface

A Python implementation of the Neuroscience Data Interface for format-independent
access to neuroscience data and analysis results.
"""

__version__ = "2.0.0"

# Core classes
from .ido import IDO
from .document import Document
from .database import Database, DirectoryDatabase
from .session import Session, SessionDir
from .element import Element
from .probe import Probe
from .epoch import Epoch, EpochSet, EpochProbeMap, findepochnode, epochrange
from .cache import Cache
from .query import Query
from .subject import Subject

# Make key classes available at package level
__all__ = [
    "IDO",
    "Document",
    "Database",
    "DirectoryDatabase",
    "Session",
    "SessionDir",
    "Element",
    "Probe",
    "Epoch",
    "EpochSet",
    "EpochProbeMap",
    "findepochnode",
    "epochrange",
    "Cache",
    "Query",
    "Subject",
    "__version__",
]
