"""
Mathematical utilities for NDI.
"""

import numpy as np
from typing import Union, List


def safe_divide(numerator: float, denominator: float, default: float = 0.0) -> float:
    """
    Safely divide, returning default if denominator is zero.

    Args:
        numerator: Numerator
        denominator: Denominator
        default: Default value if division by zero

    Returns:
        Result of division or default
    """
    if denominator == 0:
        return default
    return numerator / denominator


def clamp(value: float, min_val: float, max_val: float) -> float:
    """
    Clamp value between min and max.

    Args:
        value: Value to clamp
        min_val: Minimum value
        max_val: Maximum value

    Returns:
        Clamped value
    """
    return max(min_val, min(value, max_val))


def normalize(data: Union[List, np.ndarray], method: str = 'minmax') -> np.ndarray:
    """
    Normalize data using various methods.

    Args:
        data: Data to normalize
        method: Normalization method ('minmax', 'zscore', 'sum')

    Returns:
        Normalized data
    """
    arr = np.array(data)

    if method == 'minmax':
        min_val, max_val = arr.min(), arr.max()
        if max_val == min_val:
            return np.zeros_like(arr)
        return (arr - min_val) / (max_val - min_val)

    elif method == 'zscore':
        mean, std = arr.mean(), arr.std()
        if std == 0:
            return np.zeros_like(arr)
        return (arr - mean) / std

    elif method == 'sum':
        total = arr.sum()
        if total == 0:
            return np.zeros_like(arr)
        return arr / total

    else:
        raise ValueError(f"Unknown normalization method: {method}")
