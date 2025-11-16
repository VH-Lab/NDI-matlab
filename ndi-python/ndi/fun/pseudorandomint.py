"""
Generate pseudo-random integers for NDI.

Ported from MATLAB: src/ndi/+ndi/+fun/pseudorandomint.m
"""

import random
from typing import Optional


def pseudorandomint(min_val: int = 0, max_val: int = 2**31 - 1, seed: Optional[int] = None) -> int:
    """
    Generate a pseudo-random integer.

    Args:
        min_val: Minimum value (inclusive, default: 0)
        max_val: Maximum value (inclusive, default: 2^31-1)
        seed: Optional random seed for reproducibility

    Returns:
        Random integer between min_val and max_val (inclusive)

    Example:
        >>> num = pseudorandomint(1, 100)
        >>> print(f"Random number: {num}")
        >>> # With seed for reproducibility
        >>> num = pseudorandomint(1, 100, seed=42)
    """
    if seed is not None:
        random.seed(seed)

    return random.randint(min_val, max_val)
