"""
String manipulation utilities for NDI.
"""

import re
from typing import List


def sanitize_filename(filename: str) -> str:
    """
    Sanitize a string for use as a filename.

    Args:
        filename: Original filename

    Returns:
        Sanitized filename safe for filesystem use
    """
    # Remove or replace unsafe characters
    safe = re.sub(r'[<>:"/\\|?*]', '_', filename)
    # Remove leading/trailing spaces and dots
    safe = safe.strip('. ')
    return safe


def camel_to_snake(name: str) -> str:
    """
    Convert CamelCase to snake_case.

    Args:
        name: CamelCase string

    Returns:
        snake_case string
    """
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


def snake_to_camel(name: str) -> str:
    """
    Convert snake_case to CamelCase.

    Args:
        name: snake_case string

    Returns:
        CamelCase string
    """
    components = name.split('_')
    return ''.join(x.title() for x in components)


def truncate_string(s: str, max_length: int, suffix: str = '...') -> str:
    """
    Truncate string to maximum length with suffix.

    Args:
        s: String to truncate
        max_length: Maximum length
        suffix: Suffix to add if truncated

    Returns:
        Truncated string
    """
    if len(s) <= max_length:
        return s
    return s[:max_length - len(suffix)] + suffix
