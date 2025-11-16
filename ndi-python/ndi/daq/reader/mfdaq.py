"""
NDI Multifunction DAQ Reader - Base class for multifunction data acquisition systems.

The MFDAQReader class supports various channel types:
- analog_in (ai): Analog input
- analog_out (ao): Analog output
- auxiliary_in (ax): Auxiliary channels
- digital_in (di): Digital input
- digital_out (do): Digital output
- time (t): Time samples
- event (e): Event triggers
- marker (mk): Mark channels
- text (tx): Text channels
"""

from typing import List, Dict, Any, Optional, Tuple, Union
import numpy as np

from ..reader import Reader


class MFDAQReader(Reader):
    """
    NDI Multifunction DAQ Reader - abstract base for multifunction DAQ systems.

    This class provides the interface for reading from multifunction DAQ systems
    that sample multiple data types simultaneously. Specific hardware readers
    (Intan, Blackrock, Spike2, etc.) inherit from this class.

    Channel Types:
        - analog_in (ai): Analog input channels
        - analog_out (ao): Analog output channels
        - auxiliary_in (ax): Auxiliary input channels
        - digital_in (di): Digital input channels
        - digital_out (do): Digital output channels
        - time (t): Time sample channels
        - event (e): Event trigger channels
        - marker (mk): Marker channels (value at specified times)
        - text (tx): Text marker channels

    Examples:
        >>> # Subclass example
        >>> from ndi.daq.reader.mfdaq import MFDAQReader
        >>> # reader = IntanReader()  # Inherits from MFDAQReader
    """

    # Class constants for channel types
    CHANNEL_TYPES = [
        'analog_in', 'analog_out', 'auxiliary_in',
        'digital_in', 'digital_out',
        'event', 'marker', 'text', 'time'
    ]

    CHANNEL_ABBREV = [
        'ai', 'ao', 'ax',
        'di', 'do',
        'e', 'mk', 'tx', 't'
    ]

    def __init__(self):
        """Create a new multifunction DAQ reader."""
        super().__init__()

    def epochclock(self, epochfiles: List[str]) -> List[Any]:
        """
        Return clock types for this epoch.

        Args:
            epochfiles: List of epoch file paths

        Returns:
            List of ClockType objects

        Notes:
            Default implementation returns 'dev_local_time'.
            Subclasses may override for different clock types.
        """
        from ...time import ClockType
        return [ClockType('dev_local_time')]

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """
        Return beginning and end times for the epoch.

        Args:
            epochfiles: List of epoch file paths

        Returns:
            List of [t0, t1] pairs

        Notes:
            Base class returns [[NaN, NaN]].
            Subclasses should override to read actual times from files.
        """
        import math
        return [[math.nan, math.nan]]

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        List the channels that were sampled for this epoch.

        Args:
            epochfiles: List of epoch file paths

        Returns:
            List of channel dictionaries with fields:
            - name: Channel name (e.g., 'ai1', 'di3')
            - type: Channel type (e.g., 'analog_in', 'digital_in')
            - time_channel: Number of time channel for this data channel

        Notes:
            Base class returns empty list.
            Subclasses must override to read channel info from files.
        """
        return []

    def getchannelsepoch_ingested(self, epochfiles: List[str], session) -> \
            Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        List channels from ingested epoch data.

        Args:
            epochfiles: List of epoch file paths
            session: NDI Session object

        Returns:
            Tuple of (channels, fullchannelinfo) where:
            - channels: Simplified channel list (name, type, time_channel)
            - fullchannelinfo: Complete channel information

        Notes:
            Reads channel information from ingested document.
        """
        d = self.getingesteddocument(epochfiles, session)
        if d is None:
            return [], []

        # TODO: Extract channel list from ingested document when file format is implemented
        # For now, return empty lists
        channels = []
        fullchannelinfo = []

        return channels, fullchannelinfo

    def readchannels_epochsamples(self, channeltype: Union[str, List[str]],
                                  channel: List[int], epochfiles: List[str],
                                  s0: int, s1: int) -> np.ndarray:
        """
        Read data from specified channels for specified sample range.

        Args:
            channeltype: Channel type string or list of types (one per channel)
            channel: List of channel numbers (1-indexed)
            epochfiles: List of epoch file paths
            s0: Starting sample number (1-indexed)
            s1: Ending sample number (1-indexed)

        Returns:
            Data array with one column per channel

        Notes:
            Base class returns empty array.
            Subclasses must implement format-specific reading.
        """
        return np.array([])

    def readchannels_epochsamples_ingested(self, channeltype: Union[str, List[str]],
                                          channel: List[int], epochfiles: List[str],
                                          s0: int, s1: int, session) -> np.ndarray:
        """
        Read data from ingested epoch files.

        Args:
            channeltype: Channel type string or list of types
            channel: List of channel numbers (1-indexed)
            epochfiles: List of epoch file paths
            s0: Starting sample number
            s1: Ending sample number
            session: NDI Session object

        Returns:
            Data array with one column per channel

        Notes:
            Reads from compressed/ingested data stored in database.
            Full implementation requires file compression system.
        """
        # TODO: Implement when compression and file storage is ready
        return np.array([])

    def readevents_epochsamples(self, channeltype: Union[str, List[str]],
                                channel: List[int], epochfiles: List[str],
                                t0: float, t1: float) -> Tuple[Any, Any]:
        """
        Read events, markers, and digital events for specified time range.

        Args:
            channeltype: List of channel type strings
            channel: List of channel numbers
            epochfiles: List of epoch file paths
            t0: Start time
            t1: End time

        Returns:
            Tuple of (timestamps, data) where:
            - timestamps: Event timestamps (column vector or cell array)
            - data: Event data (type depends on channel type)

        Channel Types:
            - 'event': timestamps with data=1
            - 'marker': timestamps with numeric data
            - 'text': timestamps with text data
            - 'dep': Digital positive edge transitions
            - 'den': Digital negative edge transitions
            - 'dimp': Digital impulse (positive then negative)
            - 'dimn': Digital impulse (negative then positive)

        Notes:
            Base class returns empty lists.
            Subclasses must implement for format-specific event reading.
        """
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channel)

        # Check for derived digital channels
        derived_types = {'dep', 'den', 'dimp', 'dimn'}
        if any(ct in derived_types for ct in channeltype):
            # Would need to read digital channels and detect transitions
            # TODO: Implement when readchannels_epochsamples works
            return [], []
        else:
            # Native event reading - delegate to subclass
            return self.readevents_epochsamples_native(channeltype, channel,
                                                       epochfiles, t0, t1)

    def readevents_epochsamples_native(self, channeltype: Union[str, List[str]],
                                       channel: List[int], epochfiles: List[str],
                                       t0: float, t1: float) -> Tuple[Any, Any]:
        """
        Read native event/marker channels from files.

        Args:
            channeltype: Channel type (single string, not list)
            channel: List of channel numbers
            epochfiles: List of epoch file paths
            t0: Start time
            t1: End time

        Returns:
            Tuple of (timestamps, data)

        Notes:
            Base class returns empty lists.
            Subclasses implement format-specific event reading.
        """
        return [], []

    def samplerate(self, epochfiles: List[str], channeltype: Union[str, List[str]],
                  channel: List[int]) -> np.ndarray:
        """
        Get the sample rate for specific channels.

        Args:
            epochfiles: List of epoch file paths
            channeltype: Channel type string or list of types
            channel: List of channel numbers

        Returns:
            Array of sample rates (one per channel)

        Notes:
            Base class returns empty array.
            Subclasses must read sample rates from file headers.
        """
        return np.array([])

    def samplerate_ingested(self, epochfiles: List[str], channeltype: Union[str, List[str]],
                           channel: List[int], session) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Get sample rate and scaling from ingested data.

        Args:
            epochfiles: List of epoch file paths
            channeltype: Channel type string or list of types
            channel: List of channel numbers
            session: NDI Session object

        Returns:
            Tuple of (sr, offset, scale) arrays

        Notes:
            Reads from ingested document's channel list.
        """
        # TODO: Implement when channel list format is defined
        sr = np.array([])
        offset = np.array([])
        scale = np.array([])
        return sr, offset, scale

    def underlying_datatype(self, epochfiles: List[str], channeltype: str,
                           channel: List[int]) -> Tuple[str, np.ndarray, int]:
        """
        Get the underlying data type for a channel.

        Args:
            epochfiles: List of epoch file paths
            channeltype: Channel type (single string)
            channel: List of channel numbers

        Returns:
            Tuple of (datatype, polynomial, datasize) where:
            - datatype: NumPy dtype string (e.g., 'float64', 'uint16')
            - polynomial: Nx2 array of [offset, scale] for each channel
            - datasize: Bit size of data

        Notes:
            Used for compression and data conversion.
            Default implementation uses float64 for analog, uint8 for digital.
        """
        n_channels = len(channel)

        if channeltype in {'analog_in', 'analog_out', 'auxiliary_in', 'time'}:
            # Keep in doubles for base class
            datatype = 'float64'
            datasize = 64
            p = np.array([[0, 1]] * n_channels)
        elif channeltype in {'digital_in', 'digital_out'}:
            datatype = 'uint8'
            datasize = 8
            p = np.array([[0, 1]] * n_channels)
        elif channeltype in {'eventmarktext', 'event', 'marker', 'text'}:
            datatype = 'float64'
            datasize = 64
            p = np.array([[0, 1]] * n_channels)
        else:
            raise ValueError(f"Unknown channel type: {channeltype}")

        return datatype, p, datasize

    def ingest_epochfiles(self, epochfiles: List[str], epoch_id: str = '') -> 'Document':
        """
        Create a document with ingested/compressed epoch data.

        Args:
            epochfiles: List of epoch file paths
            epoch_id: Epoch ID string

        Returns:
            Document of type 'daqreader_mfdaq_epochdata_ingested'

        Notes:
            Full implementation requires:
            - Channel reading
            - Data compression
            - File attachment to documents
            This is a TODO for when those systems are ready.
        """
        from ...document import Document

        # TODO: Implement full ingestion when compression is ready
        # For now, create basic document structure

        sample_analog_segment = 1_000_000  # 1M samples per segment
        sample_digital_segment = 10_000_000  # 10M samples per segment

        ec = self.epochclock(epochfiles)
        ec_strings = [ct.type if hasattr(ct, 'type') else str(ct) for ct in ec]

        t0t1 = self.t0_t1(epochfiles)

        daqreader_mfdaq_epochdata_ingested = {
            'parameters': {
                'sample_analog_segment': sample_analog_segment,
                'sample_digital_segment': sample_digital_segment
            }
        }

        daqreader_epochdata_ingested = {
            'epochtable': {
                'epochclock': ec_strings,
                't0_t1': t0t1
            }
        }

        epochid_struct = {'epochid': epoch_id}

        d = Document('daqreader_mfdaq_epochdata_ingested',
                    daqreader_mfdaq_epochdata_ingested=daqreader_mfdaq_epochdata_ingested,
                    daqreader_epochdata_ingested=daqreader_epochdata_ingested,
                    epochid=epochid_struct)
        d = d.set_dependency_value('daqreader_id', self.id())

        return d

    # Static methods

    @staticmethod
    def channel_types() -> Tuple[List[str], List[str]]:
        """
        Return all possible channel types and their abbreviations.

        Returns:
            Tuple of (types, abbrev) where:
            - types: List of full channel type names
            - abbrev: List of corresponding abbreviations

        Channel Types:
            | Type          | Abbrev | Description                    |
            |---------------|--------|--------------------------------|
            | analog_in     | ai     | Analog input                   |
            | analog_out    | ao     | Analog output                  |
            | auxiliary_in  | ax     | Auxiliary input channels       |
            | digital_in    | di     | Digital input                  |
            | digital_out   | do     | Digital output                 |
            | event         | e      | Event triggers                 |
            | marker        | mk     | Markers with values            |
            | text          | tx     | Text markers                   |
            | time          | t      | Time samples                   |
        """
        return (MFDAQReader.CHANNEL_TYPES.copy(),
                MFDAQReader.CHANNEL_ABBREV.copy())

    @staticmethod
    def standardize_channel_types(channeltypes: List[str]) -> List[str]:
        """
        Convert channel type abbreviations to standard names.

        Args:
            channeltypes: List of channel type strings (may include abbreviations)

        Returns:
            List of standardized channel type names

        Examples:
            >>> MFDAQReader.standardize_channel_types(['ai', 'di', 'analog_in'])
            ['analog_in', 'digital_in', 'analog_in']
        """
        types, abbrev = MFDAQReader.channel_types()

        result = []
        for ct in channeltypes:
            if ct in abbrev:
                idx = abbrev.index(ct)
                result.append(types[idx])
            else:
                result.append(ct)

        return result

    @staticmethod
    def channelsepoch2timechannelinfo(channelsepoch: List[Dict[str, Any]],
                                     channeltype: Union[str, List[str]],
                                     channelnumber: List[int]) -> np.ndarray:
        """
        Look up time channel number for specified channels.

        Args:
            channelsepoch: Channel list from getchannelsepoch()
            channeltype: Channel type string or list
            channelnumber: Channel numbers

        Returns:
            Array of time channel numbers (NaN if not found)

        Notes:
            Each data channel references a time channel for its timestamps.
        """
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channelnumber)

        channeltype = MFDAQReader.standardize_channel_types(channeltype)
        types, abbrev = MFDAQReader.channel_types()

        tc = np.full(len(channelnumber), np.nan)

        for i, (ct, num) in enumerate(zip(channeltype, channelnumber)):
            if ct in types:
                idx = types.index(ct)
                chname = f"{abbrev[idx]}{num}"

                # Find matching channel
                for ch in channelsepoch:
                    if ch.get('name') == chname:
                        tc[i] = ch.get('time_channel', np.nan)
                        break

        return tc

    def __repr__(self) -> str:
        """String representation."""
        return f"MFDAQReader(id='{self.id()}')"
