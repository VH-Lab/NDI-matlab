"""
NDI DAQ Reader MFDAQ Blackrock - Device driver for Blackrock Microsystems NSx/NEV file format.

This class reads data from Blackrock Microsystems NSx/NEV file format.

Blackrock Microsystems: https://www.blackrockmicro.com/
"""

from typing import List, Tuple, Dict, Any, Optional
import re
import os
import numpy as np
from ..mfdaq import MFDAQReader


class Blackrock(MFDAQReader):
    """
    Blackrock reader for Blackrock Microsystems NSx/NEV file format.

    This class reads data from Blackrock Microsystems NSx (neural signal)
    and NEV (neural event) file formats.

    Examples:
        >>> from ndi.daq.reader.mfdaq import Blackrock
        >>> reader = Blackrock()
        >>> channels = reader.getchannelsepoch(epochfiles)
    """

    def __init__(self, *args):
        """
        Create a new Blackrock reader.

        Args:
            *args: Arguments passed to MFDAQReader constructor
        """
        super().__init__(*args)

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        List the channels that are available on this Blackrock device for a given set of files.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of channel dictionaries with fields:
            - 'name': The name of the channel (e.g., 'ai1')
            - 'type': The type of data stored in the channel (e.g., 'analog_in')
        """
        ns_h, nev_h, headers = self.read_blackrock_headers(epochfiles)

        channels = []

        # Add analog input channels from NS file
        if ns_h is not None and 'MetaTags' in ns_h:
            if 'ChannelID' in ns_h['MetaTags']:
                for channel_id in ns_h['MetaTags']['ChannelID']:
                    channels.append({
                        'name': f'ai{channel_id}',
                        'type': 'analog_in'
                    })

        # TODO: Add NEV channels when NEV support is implemented

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
        nev_files, nsv_files = self.filenamefromepochfiles(epochfiles)
        ns_h, nev_h, headers = self.read_blackrock_headers(epochfiles)

        # Ensure channeltype is a list
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channel)

        # Check that all channels are the same type
        unique_types = list(set(channeltype))
        if len(unique_types) != 1:
            raise ValueError('Only one type of channel may be read per function call at present.')

        data = []

        # Clamp sample bounds
        if s0 < 1:
            s0 = 1
        if ns_h and 'MetaTags' in ns_h:
            if s0 > ns_h['MetaTags']['DataPoints']:
                s0 = ns_h['MetaTags']['DataPoints']
            if s1 > ns_h['MetaTags']['DataPoints']:
                s1 = ns_h['MetaTags']['DataPoints']

        if s1 < s0:
            return np.zeros((0, len(channel)))

        # Read based on channel type
        ct = channeltype[0]
        if ct == 'ai' or ct == 'analog_in':
            # Read analog input channels
            for ch in channel:
                ch_data = self._read_blackrock_channel(nsv_files[0], ch, s0, s1)
                if data == []:
                    data = ch_data.reshape(-1, 1)
                else:
                    data = np.concatenate([data, ch_data.reshape(-1, 1)], axis=1)

        elif ct == 'time' or ct == 'timestamp':
            # Generate time array
            if ns_h and 'MetaTags' in ns_h:
                timestamp = ns_h['MetaTags'].get('Timestamp', 0)
                sampling_freq = ns_h['MetaTags'].get('SamplingFreq', 30000)

                # Time of each sample
                time_values = timestamp + ((np.arange(s0, s1 + 1) - 1) * (1.0 / sampling_freq))
                data = time_values.reshape(-1, 1)

        return data

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
        ns_h, nev_h, headers = self.read_blackrock_headers(epochfiles, channeltype, channel)

        sr = []
        for i, ch in enumerate(channel):
            ct = channeltype[i] if isinstance(channeltype, list) else channeltype

            if ct in ['ai', 'analog_in', 'time', 'timestamp']:
                if ns_h and 'MetaTags' in ns_h:
                    sr.append(ns_h['MetaTags'].get('SamplingFreq', 30000.0))
                else:
                    sr.append(30000.0)  # Default Blackrock sampling rate
            else:
                raise ValueError(f'At present, do not know how to handle Blackrock Micro channels of type {ct}.')

        return sr

    def read_blackrock_headers(self, epochfiles: List[str],
                               channeltype: Optional[Any] = None,
                               channels: Optional[List[int]] = None) -> Tuple[Optional[Dict], Optional[Dict], Dict]:
        """
        Read information from Blackrock Micro header files.

        Args:
            epochfiles: List of file paths for this epoch
            channeltype: Optional channel type (for validation)
            channels: Optional list of channel numbers (for validation)

        Returns:
            Tuple of (ns_h, nev_h, headers) where:
            - ns_h: NSx header dictionary
            - nev_h: NEV header dictionary (None for now)
            - headers: Additional header info
        """
        nev_files, nsv_files = self.filenamefromepochfiles(epochfiles)

        ns_h = None
        nev_h = None

        # Read NSx header
        if nsv_files and nsv_files[0]:
            ns_h = self._read_nsx_header(nsv_files[0])

        # Read NEV header
        if nev_files and nev_files[0]:
            # TODO: Implement NEV header reading
            nev_h = None

        # Build headers structure
        headers = {
            'ns_rate': None,
            'requestedchanneltype': [],
            'requestedchannelindexes': []
        }

        if ns_h and 'MetaTags' in ns_h:
            headers['ns_rate'] = ns_h['MetaTags'].get('SamplingFreq', None)

        # Validate requested channels if provided
        if channeltype is not None and channels is not None:
            for i, ch in enumerate(channels):
                ct = channeltype[i] if isinstance(channeltype, list) else channeltype

                if ct in ['ai', 'analog_in']:
                    if not ns_h:
                        raise ValueError('ai channels in Blackrock must be stored in .ns# files, but there is none.')

                    # Find channel in header
                    channel_ids = ns_h['MetaTags'].get('ChannelID', [])
                    try:
                        index = channel_ids.index(ch)
                        headers['requestedchannelindexes'].append(index)
                        headers['requestedchanneltype'].append(1)  # ns==1, nev==2
                    except ValueError:
                        raise ValueError(f'Channel {ch} not recorded.')
                else:
                    raise ValueError(f'At present, do not know how to handle Blackrock Micro channels of type {ct}.')

        return ns_h, nev_h, headers

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """
        Return the t0_t1 (beginning and end) epoch times for an epoch.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List containing [t0, t1] pair in seconds
        """
        ns_h, nev_h, headers = self.read_blackrock_headers(epochfiles)

        if not ns_h or 'MetaTags' not in ns_h:
            return [[0, 0]]

        # Get timestamp and duration
        timestamp = ns_h['MetaTags'].get('Timestamp', 0)
        duration_sec = ns_h['MetaTags'].get('DataDurationSec', 0)
        sampling_freq = ns_h['MetaTags'].get('SamplingFreq', 30000)

        # Time of first sample
        t0 = timestamp

        # Time of last sample = timestamp + duration - 1/samplingfreq
        t1 = timestamp + duration_sec - 1.0 / sampling_freq

        return [[t0, t1]]

    # Static helper methods

    @staticmethod
    def filenamefromepochfiles(filename_array: List[str]) -> Tuple[List[str], List[str]]:
        """
        Return the file names that correspond to the NEV/NSV files.

        Args:
            filename_array: List of full path file strings

        Returns:
            Tuple of (nevfiles, nsvfiles) where:
            - nevfiles: List of .nev files (neuro event files)
            - nsvfiles: List of .ns# files (neural signal files)

        Raises:
            ValueError: If no .ns# or .nev files found, or multiple .ns# files
        """
        # Look for .ns# files (ns1, ns2, ns3, ns4, ns5, ns6)
        nsv_pattern = r'.*\.ns\d$'
        nsvfiles = []
        for filepath in filename_array:
            if re.search(nsv_pattern, filepath, re.IGNORECASE):
                nsvfiles.append(filepath)

        # Look for .nev files
        nev_pattern = r'.*\.nev$'
        nevfiles = []
        for filepath in filename_array:
            if re.search(nev_pattern, filepath, re.IGNORECASE):
                nevfiles.append(filepath)

        if len(nsvfiles) + len(nevfiles) == 0:
            raise ValueError('No .ns# or .nev files found.')

        if len(nsvfiles) > 1:
            raise ValueError('More than 1 NS# file in this file list; do not know what to do.')

        return nevfiles, nsvfiles

    # Private helper methods for file I/O (placeholders for external dependencies)

    def _read_nsx_header(self, filename: str) -> Dict[str, Any]:
        """
        Read Blackrock NSx header.

        Args:
            filename: Path to NSx file

        Returns:
            Header dictionary

        Note:
            This is a placeholder for the external openNSx function.
            TODO: Implement or import from Blackrock SDK when available.
        """
        # TODO: Implement actual NSx header reading
        # For now, return minimal structure
        return {
            'MetaTags': {
                'ChannelID': [],
                'DataPoints': 0,
                'DataDurationSec': 0,
                'SamplingFreq': 30000,
                'Timestamp': 0
            }
        }

    def _read_blackrock_channel(self, filename: str, channel: int,
                                s0: int, s1: int) -> np.ndarray:
        """
        Read Blackrock channel data.

        Args:
            filename: Path to NSx file
            channel: Channel number
            s0: Start sample (1-indexed)
            s1: End sample (1-indexed)

        Returns:
            Data array

        Note:
            This is a placeholder for the external openNSx function.
            TODO: Implement or import from Blackrock SDK when available.
        """
        # TODO: Implement actual NSx data reading
        # The MATLAB version calls:
        # ns_out = openNSx(filename,'read','precision','double','uV','sample',
        #                  ['t:' int2str(s0) ':' int2str(s1)], ['c:' int2str(channel)])
        return np.array([])

    def __repr__(self) -> str:
        """String representation."""
        return f"Blackrock(name='{self.name if hasattr(self, 'name') else ''}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
