"""
Convert sample times to sample index numbers.

Ported from MATLAB: src/ndi/+ndi/+time/+fun/times2samples.m
"""

import numpy as np
from typing import Union, Tuple


def times2samples(
    times: Union[np.ndarray, list, float],
    t0_t1: Tuple[float, float],
    samplerate: float
) -> np.ndarray:
    """
    Convert sample times to sample index numbers.

    Given the times of samples, a range of times in the recording [t0, t1],
    and a fixed sample rate, calculate the index number of each sample.

    Args:
        times: Time value(s). Can be scalar, list, or array.
        t0_t1: Tuple of (t0, t1) representing the time range
        samplerate: Sample rate in Hz

    Returns:
        Array of sample indices (1-based) corresponding to each time

    Example:
        >>> import numpy as np
        >>> # Times 0, 1, 2 seconds with 1000 Hz sampling
        >>> samples = times2samples([0.0, 1.0, 2.0], (0.0, 10.0), 1000.0)
        >>> print(samples)  # [1, 1001, 2001]

    Notes:
        - Sample indices are 1-based (MATLAB convention)
        - Formula: s = 1 + round((t - t0) * sr)
        - Handles infinite times:
          - -Inf maps to sample 1
          - +Inf maps to last sample (1 + sr * (t1 - t0))
        - Uses rounding to nearest integer
        - Ported from MATLAB ndi.time.fun.times2samples
    """
    # Convert to numpy array
    t = np.atleast_1d(np.array(times, dtype=float))

    # Convert times to sample indices
    # Formula: s = 1 + round((t - t0) * sr)
    s = 1 + np.round((t - t0_t1[0]) * samplerate)

    # Handle negative infinity - map to first sample (1)
    neg_inf_mask = np.isinf(t) & (t < 0)
    s[neg_inf_mask] = 1

    # Handle positive infinity - map to last sample
    pos_inf_mask = np.isinf(t) & (t > 0)
    s[pos_inf_mask] = 1 + samplerate * (t0_t1[1] - t0_t1[0])

    # Convert to integer
    s = s.astype(int)

    return s
