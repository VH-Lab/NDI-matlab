"""
Tests for NDI JSON utilities - rehydrate_json_nan_null function.
"""

import pytest
from ndi.util import rehydrate_json_nan_null


class TestRehydrateJSONNanNull:
    """Test the rehydrate_json_nan_null function."""

    def test_default_replacements(self):
        """Test basic, default replacements."""
        json_in = '{"value1":"__NDI__NaN__","value2":"__NDI__Infinity__","value3":"__NDI__-Infinity__"}'
        expected_out = '{"value1":NaN,"value2":Infinity,"value3":-Infinity}'

        actual_out = rehydrate_json_nan_null(json_in)

        assert actual_out == expected_out, 'Default strings were not replaced correctly.'

    def test_multiple_occurrences(self):
        """Test multiple replacements in a single string."""
        json_in = '["__NDI__NaN__", "__NDI__Infinity__", "__NDI__NaN__", "__NDI__-Infinity__"]'
        expected_out = '[NaN, Infinity, NaN, -Infinity]'

        actual_out = rehydrate_json_nan_null(json_in)

        assert actual_out == expected_out, 'Multiple occurrences were not handled correctly.'

    def test_context_variations(self):
        """Test different contexts (end of line, followed by comma, etc.)."""
        json_in = '{"a":"__NDI__NaN__",\n"b":"__NDI__Infinity__"}'
        expected_out = '{"a":NaN,\n"b":Infinity}'

        actual_out = rehydrate_json_nan_null(json_in)

        assert actual_out == expected_out, 'Replacements with different contexts (e.g., newline) failed.'

    def test_custom_strings(self):
        """Test the ability to specify custom search strings."""
        json_in = '{"val1":"S_NAN", "val2":"S_INF", "val3":"S_NINF"}'
        expected_out = '{"val1":NaN, "val2":Infinity, "val3":-Infinity}'

        actual_out = rehydrate_json_nan_null(
            json_in,
            nan_string='"S_NAN"',
            inf_string='"S_INF"',
            ninf_string='"S_NINF"'
        )

        assert actual_out == expected_out, 'Custom string replacements failed.'

    def test_partial_custom_strings(self):
        """Test overriding only one of the custom strings."""
        json_in = '{"val1":"MY_NAN", "val2":"__NDI__Infinity__"}'
        expected_out = '{"val1":NaN, "val2":Infinity}'

        actual_out = rehydrate_json_nan_null(json_in, nan_string='"MY_NAN"')

        assert actual_out == expected_out, 'Partially overriding custom strings failed.'

    def test_no_replacement(self):
        """Test that a string without any special values is unchanged."""
        json_in = '{"a": 1, "b": "hello", "c": [1,2,3]}'

        actual_out = rehydrate_json_nan_null(json_in)

        assert actual_out == json_in, 'Function incorrectly modified a string with no special values.'

    def test_no_partial_matches(self):
        """Test that substrings are not incorrectly matched."""
        json_in = '{"a": "__NDI__NaN___but_not_really", "b": "__NDI__NaN__"}'
        expected_out = '{"a": "__NDI__NaN___but_not_really", "b": NaN}'

        actual_out = rehydrate_json_nan_null(json_in)

        assert actual_out == expected_out, 'Function incorrectly matched a partial string.'

    def test_empty_input(self):
        """Test that an empty input string is handled gracefully."""
        json_in = ''
        expected_out = ''

        actual_out = rehydrate_json_nan_null(json_in)

        assert actual_out == expected_out, 'Empty input string was not handled correctly.'
