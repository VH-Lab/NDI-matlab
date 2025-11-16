"""
NDI JSON Utilities - Helper functions for JSON processing.

This module provides utilities for handling special cases in JSON data,
particularly NaN and Infinity values.
"""

from typing import Optional


def rehydrate_json_nan_null(json_text: str,
                            nan_string: str = '"__NDI__NaN__"',
                            inf_string: str = '"__NDI__Infinity__"',
                            ninf_string: str = '"__NDI__-Infinity__"') -> str:
    """
    Replace string representations of NaN, Inf, and -Inf in JSON text.

    Replaces special string values within a JSON character string with their
    numerical equivalents that can be parsed by JSON decoders that support
    NaN, Infinity, and -Infinity.

    By default, performs the following replacements:
      - '"__NDI__NaN__"'  ->  NaN
      - '"__NDI__Infinity__"'  ->  Infinity
      - '"__NDI__-Infinity__"' -> -Infinity

    This function finds all instances of these strings, regardless of whether
    they are followed by a comma, newline, or other character. All replacements
    are done in a single pass for performance on large strings.

    Args:
        json_text: JSON string containing special value markers
        nan_string: The string to be replaced with NaN (default: '"__NDI__NaN__"')
        inf_string: The string to be replaced with Infinity (default: '"__NDI__Infinity__"')
        ninf_string: The string to be replaced with -Infinity (default: '"__NDI__-Infinity__"')

    Returns:
        JSON string with special values replaced

    Examples:
        >>> json_in = '{"value1":"__NDI__NaN__","value2":"__NDI__Infinity__"}'
        >>> json_out = rehydrate_json_nan_null(json_in)
        >>> # json_out is '{"value1":NaN,"value2":Infinity}'

        >>> # With custom search string
        >>> json_in = '{"val":"MY_NAN", "val2":"__NDI__Infinity__"}'
        >>> json_out = rehydrate_json_nan_null(json_in, nan_string='"MY_NAN"')
        >>> # json_out is '{"val":NaN, "val2":Infinity}'

    Notes:
        - Performs exact string matching, not partial matches
        - All replacements done in single pass for efficiency
        - Works with large JSON strings
    """
    # Perform all replacements in a single pass for efficiency
    old_strings = [nan_string, inf_string, ninf_string]
    new_strings = ['NaN', 'Infinity', '-Infinity']

    result = json_text
    for old, new in zip(old_strings, new_strings):
        result = result.replace(old, new)

    return result
