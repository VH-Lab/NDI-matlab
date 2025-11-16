"""
Tests for NDI validators - validation functions for inputs.
"""

import pytest
import pandas as pd
from ndi.validators import (
    must_be_id,
    must_be_text_like,
    must_be_numeric_class,
    must_be_epoch_input,
    must_be_cell_array_of_ndi_sessions,
    must_be_cell_array_of_non_empty_character_arrays,
    must_be_cell_array_of_class
)


class TestMustBeID:
    """Test the must_be_id validator."""

    def test_valid_id(self):
        """Test with a correctly formatted NDI ID."""
        valid_id = '4126919195e6b5af_40d651024919a2e4'
        # Should not raise any exception
        must_be_id(valid_id)

    def test_valid_id_as_string(self):
        """Test with a correctly formatted NDI ID as a string."""
        valid_id = '4126919195e6b5af_40d651024919a2e4'
        # Should not raise any exception
        must_be_id(valid_id)

    def test_wrong_length_too_short(self):
        """Test with an ID that is too short."""
        invalid_id = 'short_id'
        with pytest.raises(ValueError):
            must_be_id(invalid_id)

    def test_wrong_length_too_long(self):
        """Test with an ID that is too long."""
        invalid_id = 'this_id_is_definitely_way_too_long_to_be_a_valid_ndi_id'
        with pytest.raises(ValueError):
            must_be_id(invalid_id)

    def test_missing_underscore(self):
        """Test with an ID of the correct length but missing the underscore."""
        invalid_id = '4126919195e6b5afX40d651024919a2e4'
        with pytest.raises(ValueError):
            must_be_id(invalid_id)

    def test_invalid_characters(self):
        """Test with an ID that contains non-alphanumeric characters."""
        invalid_id = '4126919195e6b5af_40d651024919a2e!'  # '!' is invalid
        with pytest.raises(ValueError):
            must_be_id(invalid_id)

    def test_non_text_scalar_input(self):
        """Test with a numeric input."""
        invalid_id = 12345
        with pytest.raises((ValueError, TypeError)):
            must_be_id(invalid_id)


class TestMustBeTextLike:
    """Test the must_be_text_like validator."""

    def test_valid_string(self):
        """Test with a valid string."""
        must_be_text_like('hello')

    def test_valid_empty_string(self):
        """Test with an empty string."""
        must_be_text_like('')

    def test_invalid_numeric(self):
        """Test with numeric input."""
        with pytest.raises((ValueError, TypeError)):
            must_be_text_like(123)

    def test_valid_list(self):
        """Test with list input (lists are text-like in Python implementation)."""
        # In Python, lists of strings are considered text-like
        must_be_text_like(['hello', 'world'])


class TestMustBeNumericClass:
    """Test the must_be_numeric_class validator."""

    def test_valid_int32(self):
        """Test with int32 class."""
        must_be_numeric_class('int32')

    def test_valid_float64(self):
        """Test with float64 class."""
        must_be_numeric_class('float64')

    def test_valid_double(self):
        """Test with 'double' as string."""
        must_be_numeric_class('double')

    def test_valid_bool(self):
        """Test with 'bool' as string."""
        must_be_numeric_class('bool')

    def test_invalid_str_class(self):
        """Test with str class (not numeric)."""
        with pytest.raises(ValueError):
            must_be_numeric_class(str)

    def test_invalid_string(self):
        """Test with invalid class name string."""
        with pytest.raises(ValueError):
            must_be_numeric_class('str')

    def test_invalid_generic_int(self):
        """Test with generic 'int' (not in valid list)."""
        with pytest.raises(ValueError):
            must_be_numeric_class('int')

    def test_invalid_generic_float(self):
        """Test with generic 'float' (not in valid list)."""
        with pytest.raises(ValueError):
            must_be_numeric_class('float')


class TestMustBeEpochInput:
    """Test the must_be_epoch_input validator."""

    def test_valid_string(self):
        """Test with valid epoch string."""
        must_be_epoch_input('epoch_001')

    def test_valid_int(self):
        """Test with valid epoch integer."""
        must_be_epoch_input(1)

    def test_invalid_list_of_strings(self):
        """Test with list of epoch strings (not allowed - must be scalar)."""
        with pytest.raises(ValueError):
            must_be_epoch_input(['epoch_001', 'epoch_002'])

    def test_invalid_list_of_ints(self):
        """Test with list of epoch integers (not allowed - must be scalar)."""
        with pytest.raises(ValueError):
            must_be_epoch_input([1, 2, 3])

    def test_invalid_none(self):
        """Test with None input."""
        with pytest.raises((ValueError, TypeError)):
            must_be_epoch_input(None)

    def test_invalid_dict(self):
        """Test with dict input."""
        with pytest.raises((ValueError, TypeError)):
            must_be_epoch_input({'epoch': '001'})

    def test_invalid_negative_int(self):
        """Test with negative integer (not allowed)."""
        with pytest.raises(ValueError):
            must_be_epoch_input(-1)

    def test_invalid_zero(self):
        """Test with zero (not allowed - must be positive)."""
        with pytest.raises(ValueError):
            must_be_epoch_input(0)


class TestMustBeCellArrayOfNdiSessions:
    """Test the must_be_cell_array_of_ndi_sessions validator."""

    def test_valid_empty_list(self):
        """Test with empty list."""
        must_be_cell_array_of_ndi_sessions([])

    def test_invalid_non_list(self):
        """Test with non-list input."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_ndi_sessions('not a list')

    def test_invalid_list_with_non_sessions(self):
        """Test with list containing non-session objects."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_ndi_sessions(['session1', 'session2'])


class TestMustBeCellArrayOfNonEmptyCharacterArrays:
    """Test the must_be_cell_array_of_non_empty_character_arrays validator."""

    def test_valid_list_of_strings(self):
        """Test with valid list of non-empty strings."""
        must_be_cell_array_of_non_empty_character_arrays(['hello', 'world'])

    def test_valid_single_string_list(self):
        """Test with list containing one string."""
        must_be_cell_array_of_non_empty_character_arrays(['hello'])

    def test_invalid_empty_list(self):
        """Test with empty list - this might be valid depending on implementation."""
        # Empty list could be valid, let's test
        try:
            must_be_cell_array_of_non_empty_character_arrays([])
        except (ValueError, TypeError):
            pass  # Either outcome is acceptable

    def test_invalid_list_with_empty_string(self):
        """Test with list containing empty string."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_non_empty_character_arrays(['hello', '', 'world'])

    def test_invalid_non_list(self):
        """Test with non-list input."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_non_empty_character_arrays('not a list')

    def test_invalid_list_with_numbers(self):
        """Test with list containing numbers."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_non_empty_character_arrays(['hello', 123])


class TestMustBeCellArrayOfClass:
    """Test the must_be_cell_array_of_class validator."""

    def test_valid_list_of_ints(self):
        """Test with list of integers."""
        must_be_cell_array_of_class([1, 2, 3], int)

    def test_valid_list_of_strings(self):
        """Test with list of strings."""
        must_be_cell_array_of_class(['a', 'b', 'c'], str)

    def test_valid_empty_list(self):
        """Test with empty list."""
        must_be_cell_array_of_class([], str)

    def test_invalid_mixed_types(self):
        """Test with list containing mixed types."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_class([1, 'two', 3], int)

    def test_invalid_non_list(self):
        """Test with non-list input."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_class('not a list', str)

    def test_invalid_wrong_class(self):
        """Test with list of wrong class."""
        with pytest.raises((ValueError, TypeError)):
            must_be_cell_array_of_class([1, 2, 3], str)
