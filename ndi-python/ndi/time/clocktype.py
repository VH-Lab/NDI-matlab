"""
NDI ClockType - Specifies clock types in the NDI framework.
"""

from typing import Optional, Tuple
from enum import Enum


class ClockTypeEnum(Enum):
    """Valid clock type values."""

    UTC = 'utc'  # Universal coordinated time (within 0.1ms)
    APPROX_UTC = 'approx_utc'  # Universal coordinated time (within 5 seconds)
    EXP_GLOBAL_TIME = 'exp_global_time'  # Experiment global time (within 0.1ms)
    APPROX_EXP_GLOBAL_TIME = 'approx_exp_global_time'  # Experiment global time (within 5s)
    DEV_GLOBAL_TIME = 'dev_global_time'  # Device keeps own global time (within 0.1ms)
    APPROX_DEV_GLOBAL_TIME = 'approx_dev_global_time'  # Device keeps own global time (within 5s)
    DEV_LOCAL_TIME = 'dev_local_time'  # Device keeps own local time only within epochs
    NO_TIME = 'no_time'  # No timing information
    INHERITED = 'inherited'  # Timing information inherited from another device


class ClockType:
    """
    NDI ClockType - Specifies a clock type in the NDI framework.

    ClockType objects define the type and accuracy of timing information
    available from a device or system.
    """

    # Compatible clock type pairs for automatic epoch linking
    # Format: (type_a, type_b) -> True if compatible
    _COMPATIBLE_PAIRS = {
        ('utc', 'utc'),
        ('utc', 'approx_utc'),
        ('approx_utc', 'utc'),
        ('approx_utc', 'approx_utc'),
        ('exp_global_time', 'exp_global_time'),
        ('exp_global_time', 'approx_exp_global_time'),
        ('approx_exp_global_time', 'exp_global_time'),
        ('approx_exp_global_time', 'approx_exp_global_time'),
        ('dev_global_time', 'dev_global_time'),
        ('dev_global_time', 'approx_dev_global_time'),
        ('approx_dev_global_time', 'dev_global_time'),
        ('approx_dev_global_time', 'approx_dev_global_time'),
    }

    def __init__(self, clock_type: str = ''):
        """
        Create a new ClockType object.

        Args:
            clock_type: Type of clock. Valid values:
                - 'utc': Universal coordinated time (within 0.1ms)
                - 'approx_utc': Universal coordinated time (within 5 seconds)
                - 'exp_global_time': Experiment global time (within 0.1ms)
                - 'approx_exp_global_time': Experiment global time (within 5s)
                - 'dev_global_time': Device global time (within 0.1ms)
                - 'approx_dev_global_time': Device global time (within 5s)
                - 'dev_local_time': Device local time within epochs
                - 'no_time': No timing information
                - 'inherited': Timing inherited from another device
        """
        self._type = ''
        if clock_type:
            self.set_clocktype(clock_type)

    @property
    def type(self) -> str:
        """Get the clock type."""
        return self._type

    def set_clocktype(self, clock_type: str) -> 'ClockType':
        """
        Set the type of this ClockType.

        Args:
            clock_type: Type string (see __init__ for valid values)

        Returns:
            ClockType: Self for chaining

        Raises:
            ValueError: If clock_type is not a valid string
            ValueError: If clock_type is not a recognized type
        """
        if not isinstance(clock_type, str):
            raise ValueError("TYPE must be a string")

        clock_type = clock_type.lower()

        # Validate against enum
        valid_types = [e.value for e in ClockTypeEnum]
        if clock_type not in valid_types:
            raise ValueError(f"Unknown clock type '{clock_type}'. "
                           f"Valid types: {', '.join(valid_types)}")

        self._type = clock_type
        return self

    def epochgraph_edge(self, other: 'ClockType') -> Tuple[float, Optional['TimeMapping']]:
        """
        Provide epoch graph edge based purely on clock type.

        Returns the cost and TimeMapping that describes automatic mapping
        between epochs with different clock types.

        The following clock types are linked across epochs with cost 100
        and linear mapping (shift=1, offset=0):
        - 'utc' <-> 'utc'
        - 'utc' <-> 'approx_utc'
        - 'exp_global_time' <-> 'exp_global_time'
        - 'exp_global_time' <-> 'approx_exp_global_time'
        - 'dev_global_time' <-> 'dev_global_time'
        - 'dev_global_time' <-> 'approx_dev_global_time'

        Otherwise, cost is Inf and mapping is None.

        Args:
            other: Another ClockType object

        Returns:
            Tuple of (cost, mapping):
                - cost: Float (100 for compatible, Inf for incompatible)
                - mapping: TimeMapping object or None
        """
        from .timemapping import TimeMapping

        cost = float('inf')
        mapping = None

        # Check if this pair is compatible
        pair = (self._type, other._type)
        if pair in self._COMPATIBLE_PAIRS:
            cost = 100.0
            # Linear mapping with shift=1, offset=0
            mapping = TimeMapping('linear', [1.0, 0.0])

        return cost, mapping

    def ndi_clocktype2char(self) -> str:
        """
        Convert ClockType to character string representation.

        Returns:
            str: The clock type as a string
        """
        return self._type

    @staticmethod
    def ndi_clocktype2ndi_clocktype(clock_input) -> 'ClockType':
        """
        Convert various input types to ClockType object.

        Args:
            clock_input: Can be:
                - ClockType object (returned as-is)
                - String (converted to ClockType)

        Returns:
            ClockType: ClockType object

        Raises:
            ValueError: If input cannot be converted
        """
        if isinstance(clock_input, ClockType):
            return clock_input
        elif isinstance(clock_input, str):
            return ClockType(clock_input)
        else:
            raise ValueError(f"Cannot convert {type(clock_input)} to ClockType")

    def needsepoch(self) -> bool:
        """
        Check if this clocktype needs an epoch for full description.

        Returns:
            bool: True for 'dev_local_time', False otherwise
        """
        return self._type == 'dev_local_time'

    @staticmethod
    def assert_global(clocktype_obj: 'ClockType') -> None:
        """
        Raise error if the clocktype is not a global type.

        Args:
            clocktype_obj: ClockType to check

        Raises:
            AssertionError: If not a global type
        """
        valid_types = {'utc', 'approx_utc', 'exp_global_time',
                      'approx_exp_global_time', 'dev_global_time',
                      'approx_dev_global_time'}

        if clocktype_obj.type not in valid_types:
            raise AssertionError(
                f"ndi.time.clocktype field 'type' must be one of {', '.join(valid_types)}"
            )

    @staticmethod
    def is_global(clocktype_obj: 'ClockType') -> bool:
        """
        Check if clocktype is a global type.

        Args:
            clocktype_obj: ClockType to check

        Returns:
            bool: True if global type, False otherwise
        """
        valid_types = {'utc', 'approx_utc', 'exp_global_time',
                      'approx_exp_global_time', 'dev_global_time',
                      'approx_dev_global_time'}

        return clocktype_obj.type in valid_types

    def __eq__(self, other) -> bool:
        """
        Check equality based on clock type.

        Handles comparison with other ClockType objects or strings.
        """
        if isinstance(other, ClockType):
            return self._type == other._type
        elif isinstance(other, str):
            return self._type == other
        return False

    def __ne__(self, other) -> bool:
        """Check inequality."""
        return not self.__eq__(other)

    def __hash__(self) -> int:
        """Hash based on clock type."""
        return hash(self._type)

    def __repr__(self) -> str:
        """String representation."""
        return f"ClockType('{self._type}')"

    def __str__(self) -> str:
        """String representation."""
        return self._type
