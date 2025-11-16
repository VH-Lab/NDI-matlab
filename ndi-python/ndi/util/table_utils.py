"""
NDI Table Utilities - Helper functions for working with table/DataFrame data.

This module provides utilities for extracting and processing data from
pandas DataFrames, particularly for handling nested cell content.
"""

from typing import Any
import numpy as np
import pandas as pd


def unwrap_table_cell_content(cell_value: Any) -> Any:
    """
    Recursively unwrap content from a potentially nested table cell.

    This utility function takes a value, which is often a nested structure
    when read from a table, and unwraps it to retrieve the core data.
    It handles cases where values might be nested in lists or arrays.

    Args:
        cell_value: The value from a table cell. Can be a direct value
                   (numeric, string) or a nested list/array structure.

    Returns:
        The innermost value. If the original or any nested structure is empty,
        or if the content is an empty array, returns NaN. Strings are preserved
        as-is (including empty strings '').

    Examples:
        >>> unwrap_table_cell_content(42)
        42

        >>> unwrap_table_cell_content([42])
        42

        >>> unwrap_table_cell_content([[['deep']]])
        'deep'

        >>> unwrap_table_cell_content([])
        nan

        >>> unwrap_table_cell_content([[[]]])
        nan

        >>> unwrap_table_cell_content([''])
        ''

    Notes:
        - Non-list/array inputs are returned unchanged
        - Empty lists/arrays return NaN
        - Empty strings ('') are preserved (not converted to NaN)
        - Maximum unwrap depth of 10 to prevent infinite loops
    """
    current_value = cell_value
    unwrap_count = 0
    max_unwrap = 10  # Safety break to prevent infinite loops

    # Recursively unwrap lists/arrays
    while isinstance(current_value, (list, tuple, np.ndarray)) and unwrap_count < max_unwrap:
        # Check if empty
        if len(current_value) == 0:
            return np.nan

        # Get first element
        if isinstance(current_value, np.ndarray):
            if current_value.size == 0:
                return np.nan
            current_value = current_value.flat[0]
        else:
            current_value = current_value[0]

        unwrap_count += 1

    # Handle pandas Series (from DataFrame cells)
    if isinstance(current_value, pd.Series):
        if len(current_value) == 0:
            return np.nan
        current_value = current_value.iloc[0]

    # Check if final value is empty (but preserve empty strings)
    if current_value is None:
        return np.nan

    if isinstance(current_value, (list, tuple, np.ndarray)):
        if len(current_value) == 0:
            return np.nan

    # Empty numeric arrays -> NaN, but preserve empty strings
    if isinstance(current_value, np.ndarray):
        if current_value.size == 0 and current_value.dtype.kind != 'U':  # 'U' is Unicode string
            return np.nan

    # Check for empty non-string values
    try:
        if not isinstance(current_value, str) and pd.isna(current_value):
            return np.nan
    except (TypeError, ValueError):
        pass

    # Preserve empty strings but convert other empty values
    if hasattr(current_value, '__len__'):
        if len(current_value) == 0:
            if isinstance(current_value, (str, bytes)):
                return current_value  # Preserve empty strings
            else:
                return np.nan

    return current_value
