"""
NDI Dataset submodule - Dataset implementations.

This package contains the Dataset base class and concrete implementations.
"""

from .dataset import Dataset
from .dir import Dir

__all__ = ['Dataset', 'Dir']
