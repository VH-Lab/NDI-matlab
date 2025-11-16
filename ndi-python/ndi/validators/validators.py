"""
NDI Validators - Validation functions for NDI inputs.

This module provides validation functions that throw exceptions if inputs
don't meet specific criteria. These are intended for use in function
argument validation.
"""

from typing import Any, List, Union


def must_be_id(input_arg: Any) -> None:
    """
    Validate input is a correctly formatted NDI ID string.

    Validates that the input argument meets the NDI ID format criteria:
    - Must be a string
    - Must be exactly 33 characters long
    - Character at index 16 (0-indexed) must be an underscore ('_')
    - All other characters must be alphanumeric (A-Z, a-z, 0-9)

    Args:
        input_arg: The value to validate

    Raises:
        ValueError: If input doesn't meet NDI ID format criteria

    Examples:
        >>> must_be_id('a1b2c3d4e5f6g7h8_i9j0k1l2m3n4o5p6q')  # Valid
        >>> must_be_id('invalid')  # Raises ValueError
    """
    # Convert to string if possible
    try:
        input_str = str(input_arg)
    except Exception:
        raise ValueError('Input could not be converted to a string.')

    # Check length
    expected_length = 33
    actual_length = len(input_str)
    if actual_length != expected_length:
        raise ValueError(
            f'Input must be exactly {expected_length} characters long '
            f'(actual length was {actual_length}).'
        )

    # Check underscore at position 16 (0-indexed, position 17 in 1-indexed MATLAB)
    if input_str[16] != '_':
        raise ValueError(
            f"Character 17 must be an underscore (_), but found '{input_str[16]}'."
        )

    # Check alphanumeric for other positions
    for i in range(expected_length):
        if i == 16:  # Skip the underscore position
            continue
        if not input_str[i].isalnum():
            raise ValueError(
                f'Characters 1-16 and 18-33 must be alphanumeric (A-Z, a-z, 0-9). '
                f"Found invalid character '{input_str[i]}' at position {i+1}."
            )


def must_be_text_like(value: Any) -> None:
    """
    Validate that input is a string or list of strings.

    This function validates that the input is one of the following:
    - A string
    - A list where every element is a string

    Args:
        value: The input value to be validated

    Raises:
        ValueError: If input is not text-like

    Examples:
        >>> must_be_text_like('hello')  # Valid
        >>> must_be_text_like(['hello', 'world'])  # Valid
        >>> must_be_text_like(123)  # Raises ValueError
    """
    # Check for single string
    if isinstance(value, str):
        return

    # Check for list of strings
    if isinstance(value, list):
        if all(isinstance(x, str) for x in value):
            return

    # If we've reached this point, the type is not valid
    raise ValueError(
        'Input must be a string or a list of strings.'
    )


def must_be_numeric_class(class_name: Union[str, type]) -> None:
    """
    Validate that the input is a valid numeric or logical class name.

    Args:
        class_name: The class name or type to validate

    Raises:
        ValueError: If class_name is not a valid numeric/logical class

    Examples:
        >>> must_be_numeric_class('float64')  # Valid
        >>> must_be_numeric_class('int32')  # Valid
        >>> must_be_numeric_class('string')  # Raises ValueError
    """
    # Handle type objects
    if isinstance(class_name, type):
        class_name = class_name.__name__

    # Ensure it's a string
    if not isinstance(class_name, str):
        raise ValueError('Input to validator must be a string or type.')

    # Define valid numeric and logical class names (Python equivalents)
    valid_classes = {
        'uint8', 'uint16', 'uint32', 'uint64',
        'int8', 'int16', 'int32', 'int64',
        'float32', 'float64', 'single', 'double',
        'bool', 'logical',
        # NumPy dtypes
        'numpy.uint8', 'numpy.uint16', 'numpy.uint32', 'numpy.uint64',
        'numpy.int8', 'numpy.int16', 'numpy.int32', 'numpy.int64',
        'numpy.float32', 'numpy.float64',
        'numpy.bool_'
    }

    # Check if the input class name is valid
    if class_name not in valid_classes:
        valid_classes_str = ', '.join(sorted(valid_classes))
        raise ValueError(
            f'Value must be a valid numeric or logical class name. '
            f'Must be one of: {valid_classes_str}.'
        )


def must_be_epoch_input(v: Any) -> None:
    """
    Determine whether an input can describe an epoch.

    Validates if V is a string or a positive integer scalar.

    Note: This function does not determine if the input actually
    corresponds to a valid epoch. Instead, it merely tests whether the input
    CAN be a valid epoch according to its formatting.

    Args:
        v: The value to validate

    Raises:
        ValueError: If v is not a valid epoch input

    Examples:
        >>> must_be_epoch_input(1)  # Valid
        >>> must_be_epoch_input('t00001')  # Valid
        >>> must_be_epoch_input([1, 2, 3])  # Raises ValueError
    """
    # Try as string
    if isinstance(v, str):
        return

    # Try as positive integer scalar
    if isinstance(v, (int, float)):
        if isinstance(v, float) and not v.is_integer():
            raise ValueError(
                'Value must be a string or positive integer scalar.'
            )
        if v <= 0:
            raise ValueError(
                'Value must be a string or positive integer scalar.'
            )
        return

    # Neither valid type
    raise ValueError(
        'Value must be a string or positive integer scalar.'
    )


def must_be_cell_array_of_ndi_sessions(value: Any) -> None:
    """
    Validate that the input is a list of ndi.session objects.

    This function validates that the input is a list where every element
    is an object of a session class (SessionDir or similar).

    Args:
        value: The input value to be validated

    Raises:
        ValueError: If input is not a list of session objects

    Examples:
        >>> sessions = [SessionDir(...), SessionDir(...)]
        >>> must_be_cell_array_of_ndi_sessions(sessions)  # Valid
    """
    # Check if it's a list
    if not isinstance(value, list):
        raise ValueError('Input must be a list.')

    # If the list is not empty, check each element
    if value:
        from ..session import Session
        for i, element in enumerate(value):
            # Check if the element is a session object
            if not isinstance(element, Session):
                raise ValueError(
                    f'All elements of the list must be ndi.session objects. '
                    f'Element {i} is of class \'{type(element).__name__}\'.'
                )


def must_be_cell_array_of_non_empty_character_arrays(value: Any) -> None:
    """
    Validate that input is a list of non-empty strings.

    This function validates that the input is a list, and that every
    element within the list is a non-empty string.

    Args:
        value: The input value to be validated

    Raises:
        ValueError: If input is not a list of non-empty strings

    Examples:
        >>> must_be_cell_array_of_non_empty_character_arrays(['a', 'b'])  # Valid
        >>> must_be_cell_array_of_non_empty_character_arrays(['a', ''])  # Raises ValueError
    """
    # Check if it's a list
    if not isinstance(value, list):
        raise ValueError('Input must be a list.')

    # If the list is not empty, check each element
    if value:
        for i, element in enumerate(value):
            # Check if the element is a non-empty string
            if not (isinstance(element, str) and element):
                raise ValueError(
                    f'All elements of the list must be non-empty strings. '
                    f'Element {i} is not.'
                )


def must_be_cell_array_of_class(value: Any, required_class: type) -> None:
    """
    Validate that input is a list of objects of a specific class.

    This is a generic version of must_be_cell_array_of_ndi_sessions that
    works for any class.

    Args:
        value: The input value to be validated
        required_class: The required class type

    Raises:
        ValueError: If input is not a list of objects of required_class

    Examples:
        >>> must_be_cell_array_of_class([obj1, obj2], MyClass)  # Valid if obj1, obj2 are MyClass
    """
    # Check if it's a list
    if not isinstance(value, list):
        raise ValueError('Input must be a list.')

    # If the list is not empty, check each element
    if value:
        for i, element in enumerate(value):
            # Check if the element is of the required class
            if not isinstance(element, required_class):
                raise ValueError(
                    f'All elements of the list must be {required_class.__name__} objects. '
                    f'Element {i} is of class \'{type(element).__name__}\'.'
                )
