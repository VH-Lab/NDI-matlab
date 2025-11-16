"""
NDI Utilities - Utility functions for NDI operations.

This module provides various utility functions for working with NDI,
including table operations, hex utilities, and document utilities.
"""

from .table import vstack
from .hex import hex_diff, hex_dump, get_hex_diff_from_file_obj
from .doc import (
    find_fuid,
    find_document_by_id,
    get_document_dependencies,
    has_dependency_value
)
from .json_utils import rehydrate_json_nan_null
from .table_utils import unwrap_table_cell_content
from .datetime_utils import datestamp2datetime, datetime2datestamp

__all__ = [
    # Table utilities
    'vstack',
    'unwrap_table_cell_content',

    # Hex utilities
    'hex_diff',
    'hex_dump',
    'get_hex_diff_from_file_obj',

    # Document utilities
    'find_fuid',
    'find_document_by_id',
    'get_document_dependencies',
    'has_dependency_value',

    # JSON utilities
    'rehydrate_json_nan_null',

    # Datetime utilities
    'datestamp2datetime',
    'datetime2datestamp',
]
