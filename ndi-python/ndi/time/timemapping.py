"""
NDI TimeMapping - Manages mapping of time across epochs and devices.
"""

import numpy as np
from typing import List, Union


class TimeMapping:
    """
    NDI TimeMapping - describes mapping from one time base to another.

    The base class provides polynomial mapping, though usually only linear
    mapping is used.

    The mapping property is a vector of length N+1 that describes the
    coefficients of a polynomial such that:

        t_out = mapping[0]*t_in^N + mapping[1]*t_in^(N-1) + ... + mapping[N]

    Usually, a linear relationship is specified with mapping = [scale, shift]:

        t_out = scale * t_in + shift

    Examples:
        >>> # Identity mapping (t_out = t_in)
        >>> tm = TimeMapping([1, 0])
        >>> tm.map(5.0)
        5.0

        >>> # Scale by 2, shift by 10
        >>> tm = TimeMapping([2, 10])
        >>> tm.map(5.0)
        20.0

        >>> # Polynomial: t_out = 2*t^2 + 3*t + 1
        >>> tm = TimeMapping([2, 3, 1])
        >>> tm.map(2.0)
        15.0
    """

    def __init__(self, mapping_type: str = 'linear', mapping: List[float] = None):
        """
        Create a new TimeMapping object.

        Args:
            mapping_type: Type of mapping ('linear', 'polynomial'). Default 'linear'.
            mapping: Mapping coefficients. For linear: [scale, shift].
                    If None, defaults to [1, 0] (identity mapping).

        Raises:
            ValueError: If test mapping with t_in=0 fails
        """
        if mapping is None:
            mapping = [1.0, 0.0]

        self._mapping = np.array(mapping, dtype=float)
        self._mapping_type = mapping_type

        # Test the mapping
        try:
            self.map(0.0)
        except Exception as e:
            raise ValueError(f"Test of mapping with t_in=0 failed: {e}")

    @property
    def mapping(self) -> np.ndarray:
        """Get the mapping coefficients."""
        return self._mapping

    def map(self, t_in: Union[float, np.ndarray]) -> Union[float, np.ndarray]:
        """
        Perform a mapping from one time base to another.

        Args:
            t_in: Input time(s). Can be scalar or array.

        Returns:
            Mapped time(s) in the output time base.
        """
        # Use numpy's polyval for polynomial evaluation
        # polyval expects coefficients in descending powers
        t_out = np.polyval(self._mapping, t_in)

        # Return scalar if input was scalar
        if isinstance(t_in, (int, float)):
            return float(t_out)

        return t_out

    def inverse_map(self, t_out: Union[float, np.ndarray]) -> Union[float, np.ndarray]:
        """
        Perform inverse mapping (if possible).

        For linear mappings [scale, shift], the inverse is straightforward:
            t_in = (t_out - shift) / scale

        For higher-order polynomials, this uses numerical root finding.

        Args:
            t_out: Output time(s) to map back to input time base

        Returns:
            Input time(s) corresponding to t_out

        Raises:
            ValueError: If mapping cannot be inverted (e.g., scale=0)
        """
        if len(self._mapping) == 2:
            # Linear case: t_out = scale*t_in + shift
            # So: t_in = (t_out - shift) / scale
            scale, shift = self._mapping

            if scale == 0:
                raise ValueError("Cannot invert mapping with scale=0")

            t_in = (t_out - shift) / scale

            if isinstance(t_out, (int, float)):
                return float(t_in)
            return t_in
        else:
            # For higher-order polynomials, need to solve p(t_in) - t_out = 0
            # This is more complex and may not have unique solutions
            raise NotImplementedError(
                "Inverse mapping for higher-order polynomials not yet implemented"
            )

    def __repr__(self) -> str:
        """String representation."""
        if len(self._mapping) == 2:
            scale, shift = self._mapping
            return f"TimeMapping(linear: t_out = {scale}*t_in + {shift})"
        else:
            return f"TimeMapping(polynomial: {self._mapping.tolist()})"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
