"""
Tests for NDI Table utilities - unwrap_table_cell_content function.
"""

import pytest
import numpy as np
import pandas as pd
from ndi.util import unwrap_table_cell_content


class TestUnwrapTableCellContent:
    """Test the unwrap_table_cell_content function."""

    def test_non_list_input(self):
        """Test that inputs that are not lists/arrays are returned unchanged."""
        # Numeric
        assert unwrap_table_cell_content(42) == 42, \
            'A non-list numeric value should be returned as is.'

        # String
        assert unwrap_table_cell_content('hello') == 'hello', \
            'A non-list string value should be returned as is.'

        # Boolean
        assert unwrap_table_cell_content(True) is True, \
            'A non-list boolean value should be returned as is.'

    def test_single_list_unwrap(self):
        """Test unwrapping from a single-level list."""
        # Numeric
        assert unwrap_table_cell_content([42]) == 42, \
            'Failed to unwrap a numeric value from a single list.'

        # String
        assert unwrap_table_cell_content(['hello']) == 'hello', \
            'Failed to unwrap a string value from a single list.'

    def test_nested_list_unwrap(self):
        """Test unwrapping from multiple levels of nested lists."""
        deeply_nested_value = [[[['deep']]]]
        assert unwrap_table_cell_content(deeply_nested_value) == 'deep', \
            'Failed to unwrap a value from a deeply nested list.'

        deeply_nested_bool = [[[[[True]]]]]
        assert unwrap_table_cell_content(deeply_nested_bool) is True, \
            'Failed to unwrap a boolean from a deeply nested list.'

    def test_tuple_unwrap(self):
        """Test unwrapping from tuples."""
        # Single tuple
        assert unwrap_table_cell_content((42,)) == 42, \
            'Failed to unwrap a value from a tuple.'

        # Nested tuple
        assert unwrap_table_cell_content((((('deep',)),))) == 'deep', \
            'Failed to unwrap a value from a deeply nested tuple.'

    def test_numpy_array_unwrap(self):
        """Test unwrapping from numpy arrays."""
        # Single element array
        arr = np.array([42])
        assert unwrap_table_cell_content(arr) == 42, \
            'Failed to unwrap a value from a numpy array.'

        # Nested arrays
        nested_arr = np.array([[['hello']]])
        result = unwrap_table_cell_content(nested_arr)
        # Result might be numpy string, so compare as string
        assert str(result) == 'hello', \
            'Failed to unwrap a value from a nested numpy array.'

    def test_empty_list_input(self):
        """Test that an empty list input results in NaN."""
        empty_list = []
        unwrapped = unwrap_table_cell_content(empty_list)
        assert pd.isna(unwrapped), \
            'An empty list should unwrap to NaN.'

    def test_nested_empty_list_input(self):
        """Test that a nested empty list also unwraps to NaN."""
        nested_empty_list = [[]]
        unwrapped = unwrap_table_cell_content(nested_empty_list)
        assert pd.isna(unwrapped), \
            'A nested empty list should unwrap to NaN.'

    def test_innermost_empty_list(self):
        """Test that a list containing an empty array results in NaN."""
        inner_empty = [[[]]]
        unwrapped = unwrap_table_cell_content(inner_empty)
        assert pd.isna(unwrapped), \
            'A list containing an empty value should unwrap to NaN.'

    def test_nan_input(self):
        """Test that a list containing NaN unwraps correctly."""
        nan_list = [np.nan]
        unwrapped = unwrap_table_cell_content(nan_list)
        assert pd.isna(unwrapped), \
            'A list containing NaN should unwrap to NaN.'

        nested_nan_list = [[[np.nan]]]
        unwrapped_nested = unwrap_table_cell_content(nested_nan_list)
        assert pd.isna(unwrapped_nested), \
            'A nested list containing NaN should unwrap to NaN.'

    def test_empty_string(self):
        """Test behavior with empty strings."""
        empty_string_list = [['']]
        assert unwrap_table_cell_content(empty_string_list) == '', \
            'A nested empty string should unwrap to an empty string.'

        # Single-level empty string
        assert unwrap_table_cell_content(['']) == '', \
            'An empty string in a list should unwrap to an empty string.'

    def test_pandas_series(self):
        """Test unwrapping from pandas Series."""
        series = pd.Series([42])
        assert unwrap_table_cell_content(series) == 42, \
            'Failed to unwrap a value from a pandas Series.'

        # Empty series
        empty_series = pd.Series([])
        unwrapped = unwrap_table_cell_content(empty_series)
        assert pd.isna(unwrapped), \
            'An empty Series should unwrap to NaN.'

    def test_mixed_nested_structures(self):
        """Test unwrapping from mixed nested structures (lists, tuples, arrays)."""
        # List containing tuple containing array
        mixed = [([np.array([42])],)]
        assert unwrap_table_cell_content(mixed) == 42, \
            'Failed to unwrap from mixed nested structures.'

    def test_none_value(self):
        """Test that None unwraps to NaN."""
        assert pd.isna(unwrap_table_cell_content(None)), \
            'None should unwrap to NaN.'

        # None in a list
        assert pd.isna(unwrap_table_cell_content([None])), \
            'A list containing None should unwrap to NaN.'
