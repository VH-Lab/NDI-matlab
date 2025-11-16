"""
NDI DAQ Reader MFDAQ - Multifunction DAQ readers base class and hardware implementations.

This package provides the MFDAQReader base class and specific implementations
for various hardware systems.
"""

# First define the base class (moved from mfdaq.py to avoid circular import)
from typing import List, Dict, Any, Optional, Tuple, Union
import numpy as np

from ndi.daq.reader import Reader


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
        """Return clock types for this epoch."""
        from ....time import ClockType
        return [ClockType('dev_local_time')]

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """Return beginning and end times for the epoch."""
        import math
        return [[math.nan, math.nan]]

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """List the channels that were sampled for this epoch."""
        return []

    def getchannelsepoch_ingested(self, epochfiles: List[str], session) -> \
            Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """List channels from ingested epoch data."""
        d = self.getingesteddocument(epochfiles, session)
        if d is None:
            return [], []
        channels = []
        fullchannelinfo = []
        return channels, fullchannelinfo

    def readchannels_epochsamples(self, channeltype: Union[str, List[str]],
                                  channel: List[int], epochfiles: List[str],
                                  s0: int, s1: int) -> np.ndarray:
        """Read data from specified channels for specified sample range."""
        return np.array([])

    def readchannels_epochsamples_ingested(self, channeltype: Union[str, List[str]],
                                          channel: List[int], epochfiles: List[str],
                                          s0: int, s1: int, session) -> np.ndarray:
        """Read data from ingested epoch files."""
        return np.array([])

    def readevents_epochsamples(self, channeltype: Union[str, List[str]],
                                channel: List[int], epochfiles: List[str],
                                t0: float, t1: float) -> Tuple[Any, Any]:
        """Read events, markers, and digital events for specified time range."""
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channel)

        derived_types = {'dep', 'den', 'dimp', 'dimn'}
        if any(ct in derived_types for ct in channeltype):
            return [], []
        else:
            return self.readevents_epochsamples_native(channeltype, channel,
                                                       epochfiles, t0, t1)

    def readevents_epochsamples_native(self, channeltype: Union[str, List[str]],
                                       channel: List[int], epochfiles: List[str],
                                       t0: float, t1: float) -> Tuple[Any, Any]:
        """Read native event/marker channels from files."""
        return [], []

    def samplerate(self, epochfiles: List[str], channeltype: Union[str, List[str]],
                  channel: List[int]) -> np.ndarray:
        """Get the sample rate for specific channels."""
        return np.array([])

    def samplerate_ingested(self, epochfiles: List[str], channeltype: Union[str, List[str]],
                           channel: List[int], session) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Get sample rate and scaling from ingested data."""
        sr = np.array([])
        offset = np.array([])
        scale = np.array([])
        return sr, offset, scale

    def underlying_datatype(self, epochfiles: List[str], channeltype: str,
                           channel: List[int]) -> Tuple[str, np.ndarray, int]:
        """Get the underlying data type for a channel."""
        n_channels = len(channel)

        if channeltype in {'analog_in', 'analog_out', 'auxiliary_in', 'time'}:
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
        """Create a document with ingested/compressed epoch data."""
        from ....document import Document

        sample_analog_segment = 1_000_000
        sample_digital_segment = 10_000_000

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

    @staticmethod
    def channel_types() -> Tuple[List[str], List[str]]:
        """Return all possible channel types and their abbreviations."""
        return (MFDAQReader.CHANNEL_TYPES.copy(),
                MFDAQReader.CHANNEL_ABBREV.copy())

    @staticmethod
    def standardize_channel_types(channeltypes: List[str]) -> List[str]:
        """Convert channel type abbreviations to standard names."""
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
        """Look up time channel number for specified channels."""
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channelnumber)

        channeltype = MFDAQReader.standardize_channel_types(channeltype)
        types, abbrev = MFDAQReader.channel_types()

        tc = np.full(len(channelnumber), np.nan)

        for i, (ct, num) in enumerate(zip(channeltype, channelnumber)):
            if ct in types:
                idx = types.index(ct)
                chname = f"{abbrev[idx]}{num}"

                for ch in channelsepoch:
                    if ch.get('name') == chname:
                        tc[i] = ch.get('time_channel', np.nan)
                        break

        return tc

    def __repr__(self) -> str:
        """String representation."""
        return f"MFDAQReader(id='{self.id()}')"


# Now import hardware-specific readers (which can now import MFDAQReader from this module)
from .intan import Intan
from .blackrock import Blackrock
from .cedspike2 import CEDSpike2
from .spikegadgets import SpikeGadgets
from .ndr import NDR

__all__ = [
    'MFDAQReader',
    'Intan',
    'Blackrock',
    'CEDSpike2',
    'SpikeGadgets',
    'NDR',
]
