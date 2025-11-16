"""
NDI Database Backends

Provides multiple database backend implementations for NDI:
- Database: Abstract base class
- DirectoryDatabase: Simple file-based database
- SQLiteDatabase: SQLite-based backend with SQL query optimization
- MATLABDumbJSONDB: Simple JSON file-based storage
- MATLABDumbJSONDB2: Enhanced JSON storage with file management
"""

# Import base classes first to avoid circular imports
from .base import Database, DirectoryDatabase

# Import backend implementations
from .sqlite import SQLiteDatabase
from .matlabdumbjsondb import MATLABDumbJSONDB
from .matlabdumbjsondb2 import MATLABDumbJSONDB2

__all__ = [
    'Database',
    'DirectoryDatabase',
    'SQLiteDatabase',
    'MATLABDumbJSONDB',
    'MATLABDumbJSONDB2',
]
