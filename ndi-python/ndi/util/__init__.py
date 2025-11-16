"""
NDI Utilities - Utility functions for NDI operations.

This module provides various utility functions for working with NDI,
including table operations, hex utilities, document utilities, file I/O,
string processing, mathematics, plotting, and caching.
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

# Phase 3 new utilities
from .document_utils import merge_documents, filter_documents_by_type, sort_documents_by_timestamp
from .file_utils import ensure_dir, copy_file_safe, file_md5, get_file_size
from .string_utils import sanitize_filename, camel_to_snake, snake_to_camel, truncate_string
from .math_utils import safe_divide, clamp, normalize
from .plot_utils import check_matplotlib, setup_plot_style, save_figure, create_subplot_grid
from .cache_utils import SimpleCache

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
    'merge_documents',
    'filter_documents_by_type',
    'sort_documents_by_timestamp',

    # JSON utilities
    'rehydrate_json_nan_null',

    # Datetime utilities
    'datestamp2datetime',
    'datetime2datestamp',

    # File utilities
    'ensure_dir',
    'copy_file_safe',
    'file_md5',
    'get_file_size',

    # String utilities
    'sanitize_filename',
    'camel_to_snake',
    'snake_to_camel',
    'truncate_string',

    # Math utilities
    'safe_divide',
    'clamp',
    'normalize',

    # Plot utilities
    'check_matplotlib',
    'setup_plot_style',
    'save_figure',
    'create_subplot_grid',

    # Cache
    'SimpleCache',
]
