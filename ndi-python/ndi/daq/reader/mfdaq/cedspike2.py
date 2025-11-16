"""
NDI DAQ Reader MFDAQ CED Spike2 - Device driver for CED Spike2.

This class reads data from CED Spike2 .SMR or .SON file formats.

It depends on sigTOOL by Malcolm Lidierth (http://sigtool.sourceforge.net).
"""

from typing import List, Tuple, Dict, Any, Optional, Union
import os
import numpy as np
from ..mfdaq import MFDAQReader


class CEDSpike2(MFDAQReader):
    """
    CED Spike2 reader for CED SMR/SON file format.

    This class reads data from CED Spike2 .SMR or .SON file formats,
    supporting analog, digital, event, marker, and text channels.

    Examples:
        >>> from ndi.daq.reader.mfdaq import CEDSpike2
        >>> reader = CEDSpike2()
        >>> channels = reader.getchannelsepoch(epochfiles)
    """

    def __init__(self, *args):
        """
        Create a new CED Spike2 reader.

        Args:
            *args: Arguments passed to MFDAQReader constructor
        """
        super().__init__(*args)

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        List the channels that are available on this CED Spike2 device.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of channel dictionaries with fields:
            - 'name': The name of the channel (e.g., 'ai1', 'ev1')
            - 'type': The type of data stored in the channel
            - 'time_channel': The channel number that has time information
        """
        channels = []

        filename = self.cedspike2filelist2smrfile(epochfiles)
        header = self._read_ced_header(filename)

        if not header or 'channelinfo' not in header or not header['channelinfo']:
            return channels

        # Process each channel in header
        for ch_info in header['channelinfo']:
            # Convert CED type to MFDAQ type
            mfdaq_type = self.cedspike2headertype2mfdaqchanneltype(ch_info['kind'])

            # Get MFDAQ prefix
            from ...system.mfdaq import MFDAQSystem
            prefix = MFDAQSystem.mfdaq_prefix(mfdaq_type)

            channel_number = ch_info['number']

            # Add main channel
            channels.append({
                'name': f'{prefix}{channel_number}',
                'type': mfdaq_type,
                'time_channel': channel_number
            })

            # For analog channels, add a separate time channel
            if mfdaq_type == 'analog_in':
                channels.append({
                    'name': f't{channel_number}',
                    'type': 'time',
                    'time_channel': channel_number
                })

        return channels

    def verifyepochprobemap(self, epochprobemap: Any, epochfiles: List[str]) -> Tuple[bool, str]:
        """
        Verifies that an EPOCHPROBEMAP is compatible with a given device and the data on disk.

        Args:
            epochprobemap: NDI EpochProbeMap object
            epochfiles: List of file paths for this epoch

        Returns:
            Tuple of (is_valid, error_message)
        """
        # TODO: Implement verification when EpochProbeMap is fully defined
        return True, ''

    def readchannels_epochsamples(self, channeltype: Any, channel: List[int],
                                  epochfiles: List[str], s0: int, s1: int) -> np.ndarray:
        """
        Read the data based on specified channels.

        Args:
            channeltype: Type of channel to read (string or list of strings)
            channel: List of channel numbers to read (1-indexed)
            epochfiles: List of file paths for this epoch
            s0: Start sample (1-indexed)
            s1: End sample (1-indexed)

        Returns:
            Data array where each column contains data from an individual channel
        """
        # Ensure channeltype is a list
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channel)

        # Check that all channels are the same type
        unique_types = list(set(channeltype))
        if len(unique_types) != 1:
            raise ValueError('Only one type of channel may be read per function call at present.')

        filename = self.cedspike2filelist2smrfile(epochfiles)

        # Get sample rates
        sr = self.samplerate(epochfiles, channeltype, channel)
        sr_unique = list(set(sr))
        if len(sr_unique) != 1:
            raise ValueError('Do not know how to handle different sampling rates across channels.')

        sr_val = sr_unique[0]

        # Convert samples to time
        t0 = (s0 - 1) / sr_val
        t1 = (s1 - 1) / sr_val

        # Handle infinite times
        if np.isinf(t0) or np.isinf(t1):
            t0_orig = t0
            t1_orig = t1
            t0t1_here = self.t0_t1(epochfiles)

            if np.isinf(t0_orig):
                if t0_orig < 0:
                    t0 = t0t1_here[0][0]
                elif t0_orig > 0:
                    t0 = t0t1_here[0][1]

            if np.isinf(t1_orig):
                if t1_orig < 0:
                    t1 = t0t1_here[0][0]
                elif t1_orig > 0:
                    t1 = t0t1_here[0][1]

        # Read data for each channel
        data = []
        ct = channeltype[0]

        for ch in channel:
            if ct == 'time':
                # Read time data
                ch_data, _, _, _, time_data = self._read_ced_datafile(filename, ch, t0, t1)
                if data == []:
                    data = time_data.reshape(-1, 1)
                else:
                    data = np.concatenate([data, time_data.reshape(-1, 1)], axis=1)
            else:
                # Read regular data
                ch_data = self._read_ced_datafile(filename, ch, t0, t1)
                if data == []:
                    data = ch_data.reshape(-1, 1)
                else:
                    data = np.concatenate([data, ch_data.reshape(-1, 1)], axis=1)

        if data == []:
            data = np.array([])

        return data

    def readevents_epochsamples_native(self, channeltype: Any, channel: List[int],
                                      epochfiles: List[str], t0: float, t1: float) -> Tuple[Union[np.ndarray, List], Union[np.ndarray, List]]:
        """
        Read events or markers of specified channels for a specified epoch.

        Args:
            channeltype: Type of channel to read ('event', 'marker', 'text')
            channel: List of channel numbers to read
            epochfiles: List of file paths for this epoch
            t0: Start time
            t1: End time

        Returns:
            Tuple of (timestamps, data) where:
            - timestamps: Time of each event (or list of arrays for multiple channels)
            - data: Event data (1 for events, marker codes for markers, text for text)
        """
        # Ensure channeltype is a list
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channel)

        timestamps = []
        data = []

        filename = self.cedspike2filelist2smrfile(epochfiles)

        for i, ch in enumerate(channel):
            ct = channeltype[i]

            # Read data
            ch_data, _, _, _, ch_timestamps = self._read_ced_datafile(filename, ch, t0, t1)

            # Process based on channel type
            if ct == 'event':
                # Events are just timestamps with value 1
                ch_data = np.ones(len(ch_data))
            elif ct == 'marker':
                # Markers are 4-byte codes
                if len(ch_data) > 0:
                    # Convert 4 bytes to 32-bit integer
                    marker_values = np.sum(
                        ch_data * np.array([2**0, 2**8, 2**16, 2**24]).reshape(1, -1),
                        axis=1
                    )
                    ch_data = marker_values
            elif ct == 'text':
                # Text data - convert to list of strings
                if len(ch_data) > 0:
                    ch_data = [row.tobytes().decode('utf-8', errors='ignore').strip('\x00') for row in ch_data]

            timestamps.append(ch_timestamps)
            data.append(ch_data)

        # If single channel, return arrays directly instead of lists
        if len(channel) == 1:
            timestamps = timestamps[0]
            data = data[0]

        return timestamps, data

    def samplerate(self, epochfiles: List[str], channeltype: Any,
                  channel: List[int]) -> List[float]:
        """
        Get the sample rate for specific epoch and channel.

        Args:
            epochfiles: List of file paths for this epoch
            channeltype: Type of channel (string or list of strings)
            channel: List of channel numbers

        Returns:
            List of sample rates for each channel
        """
        filename = self.cedspike2filelist2smrfile(epochfiles)

        sr = []
        for ch in channel:
            sample_interval = self._read_ced_sampleinterval(filename, ch)
            sr.append(1.0 / sample_interval)

        return sr

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """
        Return the t0_t1 (beginning and end) epoch times for an epoch.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List containing [t0, t1] pair in seconds
        """
        filename = self.cedspike2filelist2smrfile(epochfiles)
        header = self._read_ced_header(filename)

        if not header or 'fileinfo' not in header:
            return [[0, 0]]

        # Calculate total time from header
        # t1 = dTimeBase * maxFTime * usPerTime
        fileinfo = header['fileinfo']
        t0 = 0.0  # Note: first sample is actually at 0 + 1/4 * sample_interval
        t1 = fileinfo['dTimeBase'] * fileinfo['maxFTime'] * fileinfo['usPerTime']

        return [[t0, t1]]

    def underlying_datatype(self, epochfiles: List[str], channeltype: str,
                           channel: List[int]) -> Tuple[str, Union[List[float], np.ndarray], int]:
        """
        Get the underlying data type for a channel in an epoch.

        Args:
            epochfiles: List of file paths for this epoch
            channeltype: Type of channel (string)
            channel: List of channel numbers

        Returns:
            Tuple of (datatype, polynomial, datasize) where:
            - datatype: Type suitable for fread/fwrite
            - polynomial: Conversion polynomial [offset, scale] (may be per-channel)
            - datasize: Sample size in bits
        """
        if channeltype in ['analog_in', 'analog_out']:
            # For analog channels, need to read channel-specific scaling
            filename = self.cedspike2filelist2smrfile(epochfiles)

            p = []
            for ch in channel:
                # Read channel info to get scale and offset
                info = self._read_ced_channelinfo(filename, ch)
                s2 = info['scale'] / 6553.6
                o2 = info['offset']
                p.append([-o2/s2, s2])

            datatype = 'int16'
            datasize = 16

            if len(p) == 1:
                p = p[0]
            else:
                p = np.array(p)

        elif channeltype == 'auxiliary_in':
            datatype = 'uint16'
            datasize = 16
            p = [0, 1]

        elif channeltype == 'time':
            datatype = 'float64'
            datasize = 64
            p = [0, 1]

        elif channeltype in ['digital_in', 'digital_out']:
            datatype = 'char'
            datasize = 8
            p = [0, 1]

        elif channeltype in ['eventmarktext', 'event', 'marker', 'text']:
            datatype = 'float64'
            datasize = 64
            p = [0, 1]

        else:
            raise ValueError(f'Unknown channel type {channeltype}.')

        return datatype, p, datasize

    # Static helper methods

    @staticmethod
    def cedspike2filelist2smrfile(filelist: List[str]) -> str:
        """
        Identify the .SMR file out of a file list.

        Args:
            filelist: List of full-path file names

        Returns:
            Path to the .smr file

        Raises:
            ValueError: If no .smr file found
        """
        for filepath in filelist:
            _, ext = os.path.splitext(filepath)
            if ext.lower() == '.smr':
                return filepath

        raise ValueError('Could not find any .smr file in the file list.')

    @staticmethod
    def cedspike2headertype2mfdaqchanneltype(cedspike2channeltype: int) -> str:
        """
        Convert between CED Spike2 headers and the ndi.daq.reader.mfdaq channel types.

        Args:
            cedspike2channeltype: CED channel type code (integer)

        Returns:
            MFDAQ channel type string
        """
        conversion = {
            1: 'analog_in',      # Integer waveform
            9: 'analog_in',      # Single precision floating point
            2: 'event',          # Positive-to-negative transition
            3: 'event',          # Negative-to-positive transition
            4: 'event',          # Either transition
            5: 'marker',         # Marker
            6: 'marker',         # Wavemark (Spike2-detected event)
            8: 'text'            # Text marker
        }

        if cedspike2channeltype == 7:
            raise ValueError('Channel type 7 not yet supported - programmer should look it up.')

        if cedspike2channeltype not in conversion:
            raise ValueError(f'Could not convert channeltype {cedspike2channeltype}.')

        return conversion[cedspike2channeltype]

    # Private helper methods for file I/O (placeholders for external dependencies)

    def _read_ced_header(self, filename: str) -> Dict[str, Any]:
        """
        Read CED SMR/SON header.

        Args:
            filename: Path to SMR/SON file

        Returns:
            Header dictionary

        Note:
            This is a placeholder for the external read_CED_SOMSMR_header function.
            TODO: Implement or import from sigTOOL when available.
        """
        # TODO: Implement actual CED header reading
        return {
            'channelinfo': [],
            'fileinfo': {
                'dTimeBase': 1.0e-6,
                'maxFTime': 1000000,
                'usPerTime': 1
            }
        }

    def _read_ced_datafile(self, filename: str, channel: int,
                          t0: float, t1: float) -> Union[np.ndarray, Tuple[np.ndarray, Any, Any, Any, np.ndarray]]:
        """
        Read CED SMR/SON data file.

        Args:
            filename: Path to SMR/SON file
            channel: Channel number
            t0: Start time
            t1: End time

        Returns:
            Data array, or tuple of (data, _, _, _, timestamps) for event channels

        Note:
            This is a placeholder for the external read_CED_SOMSMR_datafile function.
            TODO: Implement or import from sigTOOL when available.
        """
        # TODO: Implement actual CED data reading
        return np.array([])

    def _read_ced_sampleinterval(self, filename: str, channel: int) -> float:
        """
        Read CED SMR/SON sample interval.

        Args:
            filename: Path to SMR/SON file
            channel: Channel number

        Returns:
            Sample interval in seconds

        Note:
            This is a placeholder for the external read_CED_SOMSMR_sampleinterval function.
            TODO: Implement or import from sigTOOL when available.
        """
        # TODO: Implement actual sample interval reading
        return 0.001  # Default 1 ms

    def _read_ced_channelinfo(self, filename: str, channel: int) -> Dict[str, Any]:
        """
        Read CED SMR/SON channel info.

        Args:
            filename: Path to SMR/SON file
            channel: Channel number

        Returns:
            Channel info dictionary with 'scale' and 'offset'

        Note:
            This is a placeholder for the external SONChannelInfo function.
            TODO: Implement or import from sigTOOL when available.
        """
        # TODO: Implement actual channel info reading
        return {
            'scale': 1.0,
            'offset': 0.0
        }

    def __repr__(self) -> str:
        """String representation."""
        return f"CEDSpike2(name='{self.name if hasattr(self, 'name') else ''}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
