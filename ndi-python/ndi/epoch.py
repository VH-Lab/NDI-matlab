"""
NDI Epoch - Time-based organization of experimental data.

The Epoch system manages temporal intervals during which data acquisition occurs,
including relationships between epochs, time synchronization, and probe mappings.
"""

from typing import List, Optional, Dict, Any, Tuple, Union
from dataclasses import dataclass, field
import numpy as np

from .time.clocktype import ClockType
from .ido import IDO


@dataclass
class Epoch:
    """
    NDI Epoch - represents a temporal epoch of data.

    An epoch is an interval of time during which a DAQ system records data.
    It includes timing information across multiple clock types, relationships
    to underlying epochs, and probe/channel mappings.

    Attributes:
        epoch_number: Epoch number (0 means unknown, may change)
        epoch_id: Unique epoch ID (never changes)
        epoch_session_id: Session ID containing this epoch
        epochprobemap: Probe/channel mapping for this epoch
        epoch_clock: List of ClockType objects describing available clocks
        t0_t1: List of [t0, t1] pairs for each clock type
        epochset_object: EpochSet object that contains this epoch
        underlying_epochs: List of Epoch objects that comprise this epoch
        underlying_files: List of file paths (for file navigator epochs)

    Examples:
        >>> from ndi.time import ClockType
        >>> epoch = Epoch(
        ...     epoch_number=1,
        ...     epoch_id=IDO.unique_id(),
        ...     epoch_session_id=IDO.unique_id(),
        ...     epoch_clock=[ClockType('dev_local_time')],
        ...     t0_t1=[[0.0, 100.0]]
        ... )
    """

    epoch_number: int = 0
    epoch_id: str = ""
    epoch_session_id: str = ""
    epochprobemap: Optional[Any] = None  # Will be EpochProbeMap when implemented
    epoch_clock: List[ClockType] = field(default_factory=list)
    t0_t1: List[List[float]] = field(default_factory=list)
    epochset_object: Optional['EpochSet'] = None
    underlying_epochs: List['Epoch'] = field(default_factory=list)
    underlying_files: List[str] = field(default_factory=list)

    def __repr__(self) -> str:
        """String representation."""
        if self.epoch_id:
            id_str = self.epoch_id[:8] + '...' if len(self.epoch_id) > 8 else self.epoch_id
        else:
            id_str = 'no-id'
        return f"Epoch(number={self.epoch_number}, id='{id_str}')"


class EpochSet:
    """
    Base class for managing a set of epochs and their dependencies.

    EpochSet provides the foundation for objects that have epochs, including
    DAQ systems, probes, and other data acquisition components.

    The epochtable is cached for performance and can be reset when needed.

    Examples:
        >>> class MyEpochSet(EpochSet):
        ...     def buildepochtable(self):
        ...         # Build and return epoch table
        ...         return []
        >>> epochset = MyEpochSet()
        >>> num = epochset.numepochs()
    """

    def __init__(self):
        """Initialize EpochSet."""
        self._cached_epochtable = None
        self._cached_hashvalue = None

    def numepochs(self) -> int:
        """
        Get the number of epochs.

        Returns:
            Number of epochs in this epochset

        Notes:
            Calls epochtable() and returns the length.
        """
        et, _ = self.epochtable()
        return len(et)

    def epochtable(self) -> Tuple[List[Dict[str, Any]], Any]:
        """
        Return an epoch table that relates this object's epochs to underlying epochs.

        Returns:
            Tuple of (epochtable, hashvalue) where:
            - epochtable: List of dicts with epoch information
            - hashvalue: Hash of the epoch table for change detection

        Each dict in the epochtable contains:
            - epoch_number: Epoch number (may change)
            - epoch_id: Unique epoch ID (never changes)
            - epoch_session_id: Session ID containing this epoch
            - epochprobemap: EpochProbeMap or None
            - epoch_clock: List of ClockType objects
            - t0_t1: List of [t0, t1] pairs for each clock
            - underlying_epochs: List of dicts describing underlying epochs
              Each underlying epoch has: 'underlying', 'epoch_id',
              'epoch_session_id', 'epochprobemap', 'epoch_clock', 't0_t1'

        Notes:
            The epochtable is cached after first computation. Use
            reset_epochtable() to force a rebuild.
        """
        cached_et, cached_hash = self.cached_epochtable()
        if cached_et is None:
            et = self.buildepochtable()
            # Compute hash (simplified - in full implementation would use proper hashing)
            hashvalue = hash(str(et))

            # Cache if possible
            cache, key = self.getcache()
            if cache is not None and key is not None:
                priority = 1  # Higher than normal priority
                cache.add(key, 'epochtable-hash',
                         {'epochtable': et, 'hashvalue': hashvalue},
                         priority)

            self._cached_epochtable = et
            self._cached_hashvalue = hashvalue
        else:
            et = cached_et
            hashvalue = cached_hash

        return et, hashvalue

    def buildepochtable(self) -> List[Dict[str, Any]]:
        """
        Build an epoch table from scratch.

        Returns:
            List of epoch dicts (see epochtable() for format)

        Notes:
            This is an abstract method that subclasses must implement.
            Base class returns empty list.
        """
        return []

    def cached_epochtable(self) -> Tuple[Optional[List[Dict[str, Any]]], Optional[Any]]:
        """
        Return the cached epoch table if it exists.

        Returns:
            Tuple of (epochtable, hashvalue) or (None, None) if not cached
        """
        if self._cached_epochtable is not None:
            return self._cached_epochtable, self._cached_hashvalue

        # Try to load from session cache if available
        cache, key = self.getcache()
        if cache is not None and key is not None:
            entry = cache.lookup(key, 'epochtable-hash')
            if entry:
                data = entry[0].data
                return data.get('epochtable'), data.get('hashvalue')

        return None, None

    def reset_epochtable(self) -> None:
        """
        Reset the cached epoch table, forcing a rebuild on next access.
        """
        self._cached_epochtable = None
        self._cached_hashvalue = None

        # Also remove from session cache
        cache, key = self.getcache()
        if cache is not None and key is not None:
            cache.remove(key, 'epochtable-hash')

    def getcache(self) -> Tuple[Optional[Any], Optional[str]]:
        """
        Get the cache and key for this epochset.

        Returns:
            Tuple of (cache, key) or (None, None) if not available

        Notes:
            Subclasses should override this to provide cache access.
            Base class returns (None, None).
        """
        return None, None

    def getepocharray(self) -> List[Epoch]:
        """
        Return an array of Epoch objects from the epoch table.

        Returns:
            List of Epoch objects

        Notes:
            This converts the epochtable dicts into Epoch objects.
        """
        et, _ = self.epochtable()

        epochobjectarray = []
        for epoch_dict in et:
            # Build underlying epochs
            underlying_epochs = []
            for ue_dict in epoch_dict.get('underlying_epochs', []):
                # Get epochprobemap or empty
                epm = ue_dict.get('epochprobemap')

                # Get underlying files or epochset object
                if isinstance(ue_dict.get('underlying'), list):
                    underlying_files = ue_dict['underlying']
                    underlying_epochset_object = None
                else:
                    underlying_files = []
                    underlying_epochset_object = ue_dict.get('underlying')

                # Create underlying epoch
                e_underlying = Epoch(
                    epoch_number=0,
                    epoch_id=ue_dict.get('epoch_id', ''),
                    epoch_session_id=ue_dict.get('epoch_session_id', ''),
                    epochprobemap=epm,
                    epoch_clock=ue_dict.get('epoch_clock', []),
                    t0_t1=ue_dict.get('t0_t1', []),
                    epochset_object=underlying_epochset_object,
                    underlying_epochs=[],
                    underlying_files=underlying_files
                )
                underlying_epochs.append(e_underlying)

            # Get main epoch's epochprobemap
            epm = epoch_dict.get('epochprobemap')

            # Create main epoch
            e = Epoch(
                epoch_number=epoch_dict.get('epoch_number', 0),
                epoch_id=epoch_dict.get('epoch_id', ''),
                epoch_session_id=epoch_dict.get('epoch_session_id', ''),
                epochprobemap=epm,
                epoch_clock=epoch_dict.get('epoch_clock', []),
                t0_t1=epoch_dict.get('t0_t1', []),
                epochset_object=self,
                underlying_epochs=underlying_epochs,
                underlying_files=[]
            )
            epochobjectarray.append(e)

        return epochobjectarray

    def epochnodes(self) -> List[Dict[str, Any]]:
        """
        Return epoch nodes for use in syncgraph.

        Returns:
            List of epoch node dicts with fields:
            - epoch_id
            - epoch_session_id
            - epochprobemap
            - epoch_clock
            - t0_t1
            - underlying_epochs
            - objectname
            - objectclass

        Notes:
            Subclasses should override to provide object name/class.
            Base class returns empty list.
        """
        return []


class EpochProbeMap:
    """
    Base class for mapping probes/channels to epochs.

    EpochProbeMap describes which probes and channels are active during
    an epoch, including device information and subject associations.

    Examples:
        >>> epm = EpochProbeMap()
        >>> serialized = epm.serialize()
    """

    def __init__(self):
        """Initialize EpochProbeMap."""
        pass

    def serialize(self) -> str:
        """
        Turn the EpochProbeMap object into a string.

        Returns:
            String representation of the probe map

        Notes:
            Base class returns empty string. Subclasses should override.
        """
        return ''

    @staticmethod
    def decode(s: str) -> List[Dict[str, str]]:
        """
        Decode probe map information from a serialized string.

        Args:
            s: Serialized string

        Returns:
            List of dicts with fields:
            - name: Probe name
            - reference: Reference information
            - type: Probe type
            - devicestring: Device string
            - subjectstring: Subject string

        Notes:
            Base implementation returns empty list.
        """
        # TODO: Implement full parsing when probe map format is defined
        return []


# Utility functions

def findepochnode(epochnode: Dict[str, Any], epochnodearray: List[Dict[str, Any]]) -> List[int]:
    """
    Find occurrence(s) of an epochnode in an array of epochnodes.

    Args:
        epochnode: Single epochnode dict to search for
        epochnodearray: Array of epochnode dicts to search in

    Returns:
        List of indices where epochnode matches elements in epochnodearray

    Notes:
        If any fields in epochnode are empty or missing, that field is not
        used for matching. This allows searching for partial matches.

        The 'epochprobemap' field is not currently compared.

    Search fields (in order):
        - objectname: Name of the object
        - objectclass: Class of the object
        - epoch_id: Unique epoch ID
        - epoch_clock: ClockType object
        - epoch_session_id: Session ID
        - time_value: Time value (must fall within t0_t1 range)

    Examples:
        >>> node = {'epoch_id': 'abc123', 'objectname': 'mydaq'}
        >>> nodes = [
        ...     {'epoch_id': 'abc123', 'objectname': 'mydaq'},
        ...     {'epoch_id': 'def456', 'objectname': 'mydaq'},
        ... ]
        >>> indices = findepochnode(node, nodes)
        >>> # Returns [0] - first node matches
    """
    if not isinstance(epochnode, dict):
        raise ValueError("epochnode must be a dict")

    if not epochnodearray:
        return []

    # Start with all indices
    searchspace = list(range(len(epochnodearray)))

    # Parameters to search
    parameters = ['objectname', 'objectclass', 'epoch_id', 'epoch_clock', 'epoch_session_id', 'time_value']

    for param in parameters:
        value = epochnode.get(param)

        if value is None or value == '':
            continue  # Skip empty/missing fields

        subspacesearch = []

        if param in ['objectname', 'objectclass', 'epoch_id', 'epoch_session_id']:
            # String comparison
            for idx in searchspace:
                if epochnodearray[idx].get(param) == value:
                    subspacesearch.append(idx)

        elif param == 'epoch_clock':
            # ClockType comparison
            for idx in searchspace:
                node_clock = epochnodearray[idx].get('epoch_clock')
                if node_clock is not None and node_clock == value:
                    subspacesearch.append(idx)

        elif param == 'time_value':
            # Time value must fall within t0_t1 range
            for idx in searchspace:
                t0_t1 = epochnodearray[idx].get('t0_t1', [])
                if t0_t1 and len(t0_t1) >= 2:
                    if t0_t1[0] <= value <= t0_t1[1]:
                        subspacesearch.append(idx)

        searchspace = subspacesearch

        if not searchspace:
            break  # No matches left

    return searchspace


def epochrange(ndi_epochset_obj: EpochSet, clocktype: ClockType,
               firstEpoch: Union[int, str], lastEpoch: Union[int, str]) -> Tuple[List[str], List[Dict], np.ndarray]:
    """
    Return a range of epochs between a first and last epoch.

    Args:
        ndi_epochset_obj: EpochSet object to query
        clocktype: ClockType to use for time ranges
        firstEpoch: First epoch (number or epoch_id)
        lastEpoch: Last epoch (number or epoch_id)

    Returns:
        Tuple of (er, et, t0_t1) where:
        - er: List of epoch_ids spanning firstEpoch to lastEpoch (inclusive)
        - et: Full epochtable from the epochset
        - t0_t1: Nx2 array of [t0, t1] values for the given clocktype

    Raises:
        ValueError: If epochs not found or invalid range
        KeyError: If clocktype not found in epoch

    Examples:
        >>> from ndi.time import ClockType
        >>> er, et, times = epochrange(myprobe, ClockType('dev_local_time'), 2, 4)
        >>> # Returns epochs 2, 3, 4 with their time ranges
    """
    et, _ = ndi_epochset_obj.epochtable()

    # Find first epoch index
    if isinstance(firstEpoch, str):
        index1 = None
        for i, epoch in enumerate(et):
            if epoch.get('epoch_id') == firstEpoch:
                index1 = i
                break
        if index1 is None:
            raise ValueError(f"Could not find first epoch {firstEpoch}")
    else:
        index1 = int(firstEpoch)

    # Find last epoch index
    if isinstance(lastEpoch, str):
        index2 = None
        for i, epoch in enumerate(et):
            if epoch.get('epoch_id') == lastEpoch:
                index2 = i
                break
        if index2 is None:
            raise ValueError(f"Could not find last epoch {lastEpoch}")
    else:
        index2 = int(lastEpoch)

    # Validate range
    if index1 > index2:
        raise ValueError("firstEpoch must be before or equal to lastEpoch")

    if not (0 <= index1 < len(et)):
        raise ValueError(f"firstEpoch position must be in 0..{len(et)-1}")

    if not (0 <= index2 < len(et)):
        raise ValueError(f"lastEpoch position must be in 0..{len(et)-1}")

    # Build epoch range
    er = []
    t0_t1 = np.full((index2 - index1 + 1, 2), np.nan)

    for i in range(index1, index2 + 1):
        epoch = et[i]
        er.append(epoch.get('epoch_id', ''))

        # Find clock index
        epoch_clocks = epoch.get('epoch_clock', [])
        clock_index = None
        for j, clock in enumerate(epoch_clocks):
            if clock == clocktype:
                clock_index = j
                break

        if clock_index is None:
            raise KeyError(f"Epoch {er[-1]} lacks clocktype {clocktype.type}")

        # Get t0, t1 for this clock
        epoch_t0_t1 = epoch.get('t0_t1', [])
        if clock_index < len(epoch_t0_t1):
            t0_t1[i - index1, 0] = epoch_t0_t1[clock_index][0]
            t0_t1[i - index1, 1] = epoch_t0_t1[clock_index][1]

    return er, et, t0_t1
