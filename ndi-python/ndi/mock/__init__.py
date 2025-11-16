"""
NDI Mock Objects - Testing utilities for NDI.

This package provides mock implementations of NDI classes for testing purposes.
Mock objects have the same interface as real objects but with predefined behavior
and simplified implementations.

Ported from MATLAB: src/ndi/+ndi/+session/mock.m and src/ndi/+ndi/+mock/
"""

from .session import MockSession
from .database import MockDatabase
from .daqsystem import MockDAQSystem
from .probe import MockProbe

__all__ = ['MockSession', 'MockDatabase', 'MockDAQSystem', 'MockProbe']
