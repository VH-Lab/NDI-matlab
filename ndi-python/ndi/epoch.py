"""
NDI Epoch - Time-based organization of experimental data.
"""

from typing import List, Optional
from dataclasses import dataclass


@dataclass
class Epoch:
    """
    NDI Epoch - represents a temporal epoch of data.

    An epoch is an interval of time during which a DAQ system records data.
    """

    epoch_number: int = 0
    epoch_id: str = ""
    epoch_session_id: str = ""
    epochprobemap: List = None
    epoch_clock: List = None
    t0_t1: List = None
    epochset_object: Optional[object] = None
    underlying_epochs: List['Epoch'] = None
    underlying_files: List[str] = None

    def __post_init__(self):
        """Initialize default values."""
        if self.epochprobemap is None:
            self.epochprobemap = []
        if self.epoch_clock is None:
            self.epoch_clock = []
        if self.t0_t1 is None:
            self.t0_t1 = []
        if self.underlying_epochs is None:
            self.underlying_epochs = []
        if self.underlying_files is None:
            self.underlying_files = []

    def __repr__(self) -> str:
        """String representation."""
        return f"Epoch(number={self.epoch_number}, id='{self.epoch_id[:8]}...')"


class EpochSet:
    """
    Base class for objects that manage epochs.
    """

    def numepochs(self) -> int:
        """Get the number of epochs."""
        raise NotImplementedError()

    def epochtable(self) -> List[Epoch]:
        """Get the epoch table."""
        raise NotImplementedError()
