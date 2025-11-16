"""
NDI Table Utilities - Functions for working with tables/DataFrames.

This module provides utility functions for table operations in NDI,
primarily working with pandas DataFrames as Python equivalents of MATLAB tables.
"""

import pandas as pd
import numpy as np
from typing import List, Union, Any


def vstack(tables: List[pd.DataFrame]) -> pd.DataFrame:
    """
    Vertically concatenate DataFrames with dissimilar columns.

    This function concatenates multiple DataFrames vertically (stacking rows),
    handling cases where DataFrames have different columns. Missing columns
    are filled with appropriate typed empty values (NaN for numeric, None for
    object, NaT for datetime, etc.).

    This is the Python equivalent of MATLAB's ndi.fun.table.vstack function,
    adapted for pandas DataFrames.

    Args:
        tables: List of pandas DataFrames to concatenate vertically

    Returns:
        Single DataFrame containing all rows from input DataFrames

    Raises:
        ValueError: If tables is empty or contains non-DataFrame elements

    Examples:
        >>> df1 = pd.DataFrame({'A': [1, 2], 'B': [3, 4]})
        >>> df2 = pd.DataFrame({'B': [5, 6], 'C': [7, 8]})
        >>> result = vstack([df1, df2])
        >>> # result has columns A, B, C with NaN where missing

    Notes:
        - Missing columns are filled with NaN for numeric types
        - Missing columns are filled with None for object types
        - Missing columns are filled with NaT for datetime types
        - Column order is determined by the union of all input columns
        - Original dtypes are preserved where possible
    """
    # Validate input
    if not tables:
        raise ValueError('Input must be a non-empty list of DataFrames.')

    if not all(isinstance(t, pd.DataFrame) for t in tables):
        raise ValueError('All elements in the list must be pandas DataFrames.')

    # Handle single table case
    if len(tables) == 1:
        return tables[0].copy()

    # Collect all unique column names while preserving order
    all_columns = []
    seen_columns = set()

    for table in tables:
        for col in table.columns:
            if col not in seen_columns:
                all_columns.append(col)
                seen_columns.add(col)

    # Build list of DataFrames with all columns (adding missing ones)
    standardized_tables = []

    for table in tables:
        # Start with a copy of the table
        new_table = table.copy()

        # Find missing columns
        missing_columns = [col for col in all_columns if col not in table.columns]

        # Add missing columns with appropriate fill values
        for col in missing_columns:
            # Determine appropriate fill value based on dtype of column in other tables
            # Default to NaN, but try to infer from other tables
            fill_value = np.nan

            # Try to find this column in other tables to infer dtype
            for other_table in tables:
                if col in other_table.columns:
                    dtype = other_table[col].dtype

                    if pd.api.types.is_datetime64_any_dtype(dtype):
                        fill_value = pd.NaT
                    elif pd.api.types.is_object_dtype(dtype):
                        fill_value = None
                    elif pd.api.types.is_bool_dtype(dtype):
                        fill_value = False  # or could use None
                    elif pd.api.types.is_integer_dtype(dtype):
                        # For integers, use NaN (will convert to float) or could use 0
                        fill_value = np.nan
                    elif pd.api.types.is_float_dtype(dtype):
                        fill_value = np.nan
                    else:
                        fill_value = None

                    break

            # Add column with fill values
            new_table[col] = fill_value

        # Reorder columns to match all_columns
        new_table = new_table[all_columns]

        standardized_tables.append(new_table)

    # Concatenate all tables
    result = pd.concat(standardized_tables, ignore_index=True, copy=False)

    return result


def identify_valid_rows(table: pd.DataFrame,
                       non_nan_variable_names: List[str]) -> np.ndarray:
    """
    Identify valid rows in a DataFrame based on non-NaN requirements.

    A row is considered valid if all columns specified in non_nan_variable_names
    contain non-NaN values.

    Args:
        table: DataFrame to check
        non_nan_variable_names: List of column names that must not contain NaN

    Returns:
        Boolean array where True indicates a valid row

    Examples:
        >>> df = pd.DataFrame({
        ...     'A': [1, 2, np.nan, 4],
        ...     'B': [5, np.nan, 7, 8]
        ... })
        >>> valid = identify_valid_rows(df, ['A', 'B'])
        >>> # valid is [True, False, False, True]

    Notes:
        - If non_nan_variable_names is empty, all rows are considered valid
        - Missing columns in table are treated as all-NaN
    """
    if not non_nan_variable_names:
        # All rows are valid if no constraints
        return np.ones(len(table), dtype=bool)

    # Start with all rows valid
    valid = np.ones(len(table), dtype=bool)

    for col_name in non_nan_variable_names:
        if col_name not in table.columns:
            # Column doesn't exist - all rows invalid for this column
            valid[:] = False
        else:
            # Mark rows with NaN in this column as invalid
            valid &= ~table[col_name].isna()

    return valid
