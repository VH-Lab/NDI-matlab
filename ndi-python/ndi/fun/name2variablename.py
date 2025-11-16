"""
name2variableName - Convert a string into a camelCase variable name format.

This module provides the name2variableName function which converts arbitrary
strings into valid Python variable names in camelCase format.
"""

import re
from typing import Union, List


def name2variableName(name: Union[str, List[str]]) -> Union[str, List[str]]:
    """
    Convert a string into a camelCase variable name format.

    This function takes a string or list of strings and converts them into
    valid variable names suitable for use in Python.

    Steps:
    1. Replace colons and hyphens with underscores
    2. Replace non-alphanumeric characters (except underscore) with spaces
    3. Split into words
    4. Capitalize the first letter of each word
    5. Join words together without spaces
    6. Ensure name starts with a letter (prepend 'var_' if needed)
    7. Final cleanup to remove invalid characters

    Args:
        name: The raw input string or list of strings to convert

    Returns:
        Processed string(s) formatted as camelCase variable name(s)

    Examples:
        >>> name2variableName('hello world')
        'HelloWorld'
        >>> name2variableName('CL:0000000')
        'CL_0000000'
        >>> name2variableName('test-name')
        'Test_Name'
        >>> name2variableName(['hello', 'world'])
        ['Hello', 'World']
    """
    # Handle list input
    if isinstance(name, list):
        return [name2variableName(n) for n in name]

    # Handle empty or whitespace-only strings
    if not name or not name.strip():
        return ''

    current_str = name

    # Step 1: Replace select characters with an underscore
    current_str = current_str.replace(':', '_')
    current_str = current_str.replace('-', '_')

    # Step 2: Replace non-alphanumeric characters (except underscore) with spaces
    cleaned = re.sub(r'[^a-zA-Z0-9_]', ' ', current_str)

    # Step 3: Split into words
    words = cleaned.split()

    # Step 4: Capitalize first letter of each word
    capitalized_words = []
    for word in words:
        if word:  # Non-empty word
            # Capitalize first letter, keep rest as-is
            capitalized = word[0].upper() + word[1:] if len(word) > 1 else word[0].upper()
            capitalized_words.append(capitalized)

    # Step 5: Join words together
    result = ''.join(capitalized_words)

    # Step 6: Ensure name starts with a letter
    if result and not result[0].isalpha():
        result = 'var_' + result

    # Step 7: Final cleanup - remove any remaining invalid characters
    result = re.sub(r'[^a-zA-Z0-9_]', '', result)

    return result
