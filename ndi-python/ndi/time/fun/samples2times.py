"""
Convert sample index numbers to sample times.

Ported from MATLAB: src/ndi/+ndi/+time/+fun/samples2times.m
"""

import numpy as np
from typing import Union, Tuple


def samples2times(
    samples: Union[np.ndarray, list, int, float],
    t0_t1: Tuple[float, float],
    samplerate: float
) -> np.ndarray:
    """
    Convert sample index numbers to sample times.

    Given the index numbers of samples, a range of times in the recording
    [t0, t1], and a fixed sample rate, calculate the time of each sample.

    Args:
        samples: Sample index number(s). Can be scalar, list, or array.
                Sample indices are 1-based (first sample is index 1)
        t0_t1: Tuple of (t0, t1) representing the time range
        samplerate: Sample rate in Hz

    Returns:
        Array of times corresponding to each sample index

    Example:
        >>> import numpy as np
        >>> # Sample 1 at t=0, sample rate 1000 Hz
        >>> times = samples2times([1, 1001, 2001], (0.0, 10.0), 1000.0)
        >>> print(times)  # [0.0, 1.0, 2.0]

    Notes:
        - Sample indices are 1-based (MATLAB convention)
        - Formula: t = (s - 1) / sr + t0
        - Handles infinite sample indices:
          - -Inf maps to t0
          - +Inf maps to t1
        - Ported from MATLAB ndi.time.fun.samples2times
    """
    # Convert to numpy array
    s = np.atleast_1d(np.array(samples, dtype=float))

    # Convert sample indices to times
    # Formula: s = 1 + (t - t0) * sr
    # Solving for t: t = (s - 1) / sr + t0
    t = (s - 1) / samplerate + t0_t1[0]

    # Handle negative infinity - map to t0
    neg_inf_mask = np.isinf(s) & (s < 0)
    t[neg_inf_mask] = t0_t1[0]

    # Handle positive infinity - map to t1
    pos_inf_mask = np.isinf(s) & (s > 0)
    t[pos_inf_mask] = t0_t1[1]

    return t
