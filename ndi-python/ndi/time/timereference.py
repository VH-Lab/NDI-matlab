"""
NDI TimeReference - Specifies time relative to an NDI clock.

This module provides the TimeReference class for specifying precise
time references within the NDI system.
"""

from typing import Optional, Any, Dict
from .clocktype import ClockType


class TimeReference:
    """
    TimeReference - Specifies time relative to an NDI clock.

    A TimeReference uniquely specifies a time by combining:
    - A referent object (ndi.epoch.epochset subclass)
    - A clock type
    - An epoch (if using dev_local_time)
    - A time value

    Attributes:
        referent: The object that is referred to (ndi.daq.system, ndi.element, etc.)
        clocktype: The clock type (ClockType object)
        epoch: The epoch identifier (required for dev_local_time)
        time: The time value
        session_id: The ID of the session containing this time

    Examples:
        >>> from ndi.time import TimeReference, ClockType
        >>> # Create time reference with local time
        >>> tr = TimeReference(my_probe, ClockType('dev_local_time'), 'epoch_001', 10.5)
        >>> # Create time reference with UTC
        >>> tr = TimeReference(my_device, ClockType('utc'), None, 1234567890.0)
    """

    def __init__(self, referent: Any, clocktype: ClockType,
                 epoch: Optional[str] = None, time: Optional[float] = None):
        """
        Create a new TimeReference object.

        Args:
            referent: Any subclass of ndi.epoch.epochset with a 'session' property
            clocktype: The clock type (ClockType object or will be converted)
            epoch: The epoch identifier (required if clocktype needs epoch)
            time: The time value

        Raises:
            ValueError: If referent is not an EpochSet or doesn't have a session
            ValueError: If clocktype needs epoch but epoch is not provided
        """
        # Validate referent
        from ..epoch import EpochSet
        if not isinstance(referent, EpochSet):
            raise ValueError("referent must be a subclass of ndi.epoch.epochset")

        if not hasattr(referent, 'session'):
            raise ValueError("The referent must have a session property")

        if referent.session is None:
            raise ValueError("The referent must have a valid session")

        session_id = referent.session.id()

        # Validate and convert clocktype
        if not isinstance(clocktype, ClockType):
            clocktype = ClockType(clocktype)

        # Check if epoch is required
        if clocktype.needsepoch():
            if epoch is None or epoch == '':
                raise ValueError("clocktype requires an EPOCH to be specified")

        # Set attributes
        self.referent = referent
        self.session_id = session_id
        self.clocktype = clocktype
        self.epoch = epoch
        self.time = time

    def to_struct(self) -> Dict[str, Any]:
        """
        Return a structure describing this time reference.

        Returns:
            Dictionary with fields:
            - referent_epochsetname: The epochsetname() of the referent
            - referent_classname: The classname of the referent
            - clocktypestring: The clock type string
            - epoch: The epoch identifier
            - session_id: The session ID
            - time: The time value

        Notes:
            This structure can be serialized and later reconstructed
            using from_struct().
        """
        return {
            'referent_epochsetname': self.referent.epochsetname() if hasattr(self.referent, 'epochsetname') else '',
            'referent_classname': type(self.referent).__name__,
            'clocktypestring': str(self.clocktype),
            'epoch': self.epoch,
            'session_id': self.session_id,
            'time': self.time
        }

    @classmethod
    def from_struct(cls, session: Any, timeref_struct: Dict[str, Any]) -> 'TimeReference':
        """
        Create TimeReference from a structure.

        Args:
            session: The ndi.session object
            timeref_struct: Structure from to_struct()

        Returns:
            New TimeReference object

        Raises:
            ValueError: If referent cannot be found in session
        """
        # Find the referent object in the session
        if hasattr(session, 'findexpobj'):
            referent = session.findexpobj(
                timeref_struct['referent_epochsetname'],
                timeref_struct['referent_classname']
            )
        else:
            raise ValueError("Session does not support findexpobj")

        if referent is None:
            raise ValueError(f"Could not find referent {timeref_struct['referent_epochsetname']}")

        # Create clock type
        clocktype = ClockType(timeref_struct['clocktypestring'])

        # Create time reference
        return cls(
            referent=referent,
            clocktype=clocktype,
            epoch=timeref_struct['epoch'],
            time=timeref_struct['time']
        )

    def __repr__(self) -> str:
        """String representation."""
        epoch_str = f", epoch='{self.epoch}'" if self.epoch else ""
        return f"TimeReference({self.clocktype}{epoch_str}, time={self.time})"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
