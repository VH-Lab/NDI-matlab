"""
NDI DAQ Reader MFDAQ SpikeGadgets - Device driver for SpikeGadgets .rec video file format.

This class reads data from video files .rec that SpikeGadgets uses.

SpikeGadgets: http://spikegadgets.com/
"""

from typing import List, Tuple, Dict, Any, Optional
import re
import os
import numpy as np
from ..mfdaq import MFDAQReader


class SpikeGadgets(MFDAQReader):
    """
    SpikeGadgets reader for SpikeGadgets .rec file format.

    This class reads data from SpikeGadgets .rec files, supporting
    analog inputs, auxiliary inputs, digital inputs/outputs, and nTrodes.

    Examples:
        >>> from ndi.daq.reader.mfdaq import SpikeGadgets
        >>> reader = SpikeGadgets()
        >>> channels = reader.getchannelsepoch(epochfiles)
    """

    def __init__(self, *args):
        """
        Create a new SpikeGadgets reader.

        Args:
            *args: Arguments passed to MFDAQReader constructor
        """
        super().__init__(*args)

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        Get the channels available from .rec file header.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of channel dictionaries with fields:
            - 'name': The name of the channel (e.g., 'ai1', 'di1', 'ax1')
            - 'type': The type of data stored in the channel
        """
        filename = self.filenamefromepochfiles(epochfiles)
        fileconfig, channels_raw = self._read_spikegadgets_config(filename)

        channels = []

        # Process auxiliary and digital channels
        for ch_raw in channels_raw:
            ch_name = ch_raw.get('name', '')
            number = 0
            name = ''
            ch_type = ''
            time_channel = 1

            # Auxiliary channels
            if ch_name.startswith('A'):
                if len(ch_name) > 1 and ch_name[1] == 'i':
                    # Ain# - Auxiliary input
                    ch_type = 'auxiliary'
                    number = self._parse_channel_number(ch_name, 'Ain')
                    name = f'axn{number}'
                elif len(ch_name) > 1 and ch_name[1] == 'o':
                    # Aout# - Auxiliary output
                    ch_type = 'auxiliary'
                    number = self._parse_channel_number(ch_name, 'Aout')
                    name = f'axo{number}'

            # Digital channels
            elif ch_name.startswith('D'):
                if len(ch_name) > 1 and ch_name[1] == 'i':
                    # Din# - Digital input
                    ch_type = 'digital_in'
                    number = self._parse_channel_number(ch_name, 'Din')
                    name = f'di{number}'
                elif len(ch_name) > 1 and ch_name[1] == 'o':
                    # Dout# - Digital output
                    ch_type = 'digital_out'
                    number = self._parse_channel_number(ch_name, 'Dout')
                    name = f'do{number}'

            # MCU digital inputs
            elif ch_name.startswith('MCU_Din'):
                ch_type = 'digital_in'
                number = self._parse_channel_number(ch_name, 'MCU_Din')
                number += 32  # Offset from non-MCU inputs
                name = f'di{number}'

            if name:
                channels.append({
                    'name': name,
                    'type': ch_type,
                    'time_channel': time_channel
                })

        # Add nTrode channels (analog inputs)
        if fileconfig and 'nTrodes' in fileconfig:
            for ntrode in fileconfig['nTrodes']:
                if 'channelInfo' in ntrode:
                    for ch_info in ntrode['channelInfo']:
                        channel_number = ch_info['packetLocation'] + 1  # 1-indexed
                        channels.append({
                            'name': f'ai{channel_number}',
                            'type': 'analog_in',
                            'number': channel_number,
                            'time_channel': 1
                        })

        # Sort channels by type and number
        channels.sort(key=lambda x: (x.get('type', ''), x.get('number', 0)))

        return channels

    def samplerate(self, epochfiles: List[str], channeltype: Any,
                  channel: List[int]) -> List[float]:
        """
        Get the sample rate for specific epoch and channel.

        Args:
            epochfiles: List of file paths for this epoch
            channeltype: Type of channel (not used - same for all)
            channel: List of channel numbers (not used - same for all)

        Returns:
            List of sample rates (same value repeated)

        Note:
            Sampling rate is the same for all channels in SpikeGadgets.
        """
        filename = self.filenamefromepochfiles(epochfiles)
        fileconfig, _ = self._read_spikegadgets_config(filename)

        if fileconfig and 'samplingRate' in fileconfig:
            sr_val = float(fileconfig['samplingRate'])
        else:
            sr_val = 30000.0  # Default

        # Return same sample rate for all channels
        return [sr_val] * len(channel)

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """
        Return the t0_t1 (beginning and end) epoch times for an epoch.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List containing [t0, t1] pair in seconds
        """
        filename = self.filenamefromepochfiles(epochfiles)
        fileconfig, _ = self._read_spikegadgets_config(filename)

        if not fileconfig:
            return [[0, 0]]

        # Get file parameters
        header_size_bytes = int(fileconfig.get('headerSize', 0)) * 2  # int16 = 2 bytes
        num_channels = int(fileconfig.get('numChannels', 0))
        channel_size_bytes = num_channels * 2  # int16 = 2 bytes
        block_size_bytes = header_size_bytes + 2 + channel_size_bytes

        # Get file size
        file_size = os.path.getsize(filename)

        # Calculate number of data blocks
        num_data_blocks = (file_size - header_size_bytes) / block_size_bytes

        # Calculate total time
        total_samples = num_data_blocks
        sampling_rate = float(fileconfig.get('samplingRate', 30000))
        total_time = (total_samples - 1) / sampling_rate

        t0 = 0
        t1 = total_time

        return [[t0, t1]]

    def getepochprobemap(self, epochmapfilename: str, epochfiles: List[str]) -> List[Any]:
        """
        Get epoch probe map with probe information (name, reference, n-trode, channels).

        Args:
            epochmapfilename: Epoch map filename (not used for SpikeGadgets)
            epochfiles: List of file paths for this epoch

        Returns:
            List of epoch probe map objects
        """
        filename = self.filenamefromepochfiles(epochfiles)
        fileconfig, _ = self._read_spikegadgets_config(filename)

        if not fileconfig or 'nTrodes' not in fileconfig:
            return []

        epochprobemap = []
        nTrodes = fileconfig['nTrodes']

        for ntrode in nTrodes:
            name = f"Tetrode{ntrode['id']}"
            reference = 1
            probe_type = 'n-trode'
            channels = []

            # Get channels for this nTrode
            if 'channelInfo' in ntrode:
                for ch_info in ntrode['channelInfo']:
                    channels.append(ch_info['packetLocation'] + 1)

            # Create device string
            from ...system.daqsystemstring import DAQSystemString
            devicestring_obj = DAQSystemString(
                'SpikeGadgets',
                ['ai'] * len(channels),
                channels
            )
            devicestring = devicestring_obj.devicestring()

            # Create epoch probe map
            # TODO: Subject needs to be specified somehow
            from ....epoch import EpochProbeMapDAQSystem
            obj = EpochProbeMapDAQSystem(
                name,
                reference,
                probe_type,
                devicestring,
                'subject@lab.org'  # Placeholder
            )

            epochprobemap.append(obj)

        return epochprobemap

    def readchannels_epochsamples(self, channeltype: Any, channels: List[int],
                                  epochfiles: List[str], s0: int, s1: int) -> np.ndarray:
        """
        Read the data based on specified channels.

        Args:
            channeltype: Type of channel to read (string or list of strings)
            channels: List of channel numbers to read (1-indexed)
            epochfiles: List of file paths for this epoch
            s0: Start sample (1-indexed)
            s1: End sample (1-indexed)

        Returns:
            Data array where each column contains data from an individual channel
        """
        filename = self.filenamefromepochfiles(epochfiles)
        header, _ = self._read_spikegadgets_config(filename)

        if not header:
            return np.array([])

        sr = self.samplerate(epochfiles, channeltype, channels)
        detailed_channels = self._get_detailed_channels(epochfiles)

        data = []

        # Ensure channeltype is a list
        if not isinstance(channeltype, list):
            channeltype = [channeltype]

        ct = channeltype[0]

        # Read based on channel type
        from ...system.mfdaq import MFDAQSystem
        mfdaq_type = MFDAQSystem.mfdaq_type(ct)

        if mfdaq_type in ['analog_in', 'analog_out']:
            # Read analog nTrode channels
            # Channels are 0-indexed in file
            data = self._read_spikegadgets_trode_channels(
                filename,
                header['numChannels'],
                [ch - 1 for ch in channels],  # Convert to 0-indexed
                sr[0],
                header['headerSize'],
                s0,
                s1
            )

        elif ct in ['auxiliary', 'aux']:
            # Read auxiliary channels
            byteandbit = []
            for ch in channels:
                # Find byte location in detailed channels
                for det_ch in detailed_channels:
                    if det_ch.get('type') == 'auxiliary' and det_ch.get('number') == ch:
                        byteandbit.append(int(det_ch['startbyte']))
                        break

            data = self._read_spikegadgets_analog_channels(
                filename,
                header['numChannels'],
                byteandbit,
                sr[0],
                header['headerSize'],
                s0,
                s1
            )

        elif ct in ['digital_in', 'digital_out']:
            # Read digital channels
            byteandbit = []
            for ch in channels:
                # Find byte and bit location in detailed channels
                for det_ch in detailed_channels:
                    if det_ch.get('type') == ct and det_ch.get('number') == ch:
                        byteandbit.append([
                            int(det_ch['startbyte']),
                            int(det_ch['bit']) + 1
                        ])
                        break

            data = self._read_spikegadgets_digital_channels(
                filename,
                header['numChannels'],
                byteandbit,
                sr[0],
                header['headerSize'],
                s0,
                s1
            )

            if isinstance(data, np.ndarray):
                data = data.T

        return data if isinstance(data, np.ndarray) else np.array(data)

    def filenamefromepochfiles(self, filename_array: List[str]) -> str:
        """
        Extract the .rec filename from epoch files.

        Args:
            filename_array: List of file paths

        Returns:
            Path to .rec file

        Raises:
            ValueError: If no .rec file found or multiple .rec files
        """
        rec_pattern = r'.*\.rec$'
        matching_files = []

        for filepath in filename_array:
            if re.search(rec_pattern, filepath, re.IGNORECASE):
                matching_files.append(filepath)

        if len(matching_files) > 1:
            raise ValueError('Need only 1 .rec file per epoch.')
        elif len(matching_files) == 0:
            raise ValueError('Need 1 .rec file per epoch.')

        return matching_files[0]

    # Private helper methods

    def _parse_channel_number(self, name: str, prefix: str) -> int:
        """
        Parse channel number from name.

        Args:
            name: Channel name (e.g., 'Ain5', 'Din3')
            prefix: Prefix to remove (e.g., 'Ain', 'Din')

        Returns:
            Channel number
        """
        try:
            return int(name.replace(prefix, ''))
        except ValueError:
            return 0

    def _get_detailed_channels(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        Get detailed channel information (internal method).

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of channel dictionaries with extra details

        Note:
            This is similar to getchannelsepoch but keeps extra fields
            like 'startbyte', 'bit', 'number' for internal use.
        """
        filename = self.filenamefromepochfiles(epochfiles)
        fileconfig, channels_raw = self._read_spikegadgets_config(filename)

        channels = []

        # Process channels with extra details
        for ch_raw in channels_raw:
            ch_name = ch_raw.get('name', '')
            ch_dict = ch_raw.copy()

            # Parse channel type and number
            if ch_name.startswith('Ain'):
                ch_dict['type'] = 'auxiliary'
                ch_dict['number'] = self._parse_channel_number(ch_name, 'Ain')
            elif ch_name.startswith('Aout'):
                ch_dict['type'] = 'auxiliary'
                ch_dict['number'] = self._parse_channel_number(ch_name, 'Aout')
            elif ch_name.startswith('Din'):
                ch_dict['type'] = 'digital_in'
                ch_dict['number'] = self._parse_channel_number(ch_name, 'Din')
            elif ch_name.startswith('Dout'):
                ch_dict['type'] = 'digital_out'
                ch_dict['number'] = self._parse_channel_number(ch_name, 'Dout')
            elif ch_name.startswith('MCU_Din'):
                ch_dict['type'] = 'digital_in'
                ch_dict['number'] = self._parse_channel_number(ch_name, 'MCU_Din') + 32

            channels.append(ch_dict)

        return channels

    # Placeholders for external file reading functions

    def _read_spikegadgets_config(self, filename: str) -> Tuple[Optional[Dict], List[Dict]]:
        """
        Read SpikeGadgets .rec file configuration.

        Args:
            filename: Path to .rec file

        Returns:
            Tuple of (fileconfig, channels) where:
            - fileconfig: Configuration dictionary
            - channels: List of channel dictionaries

        Note:
            This is a placeholder for the external read_SpikeGadgets_config function.
            TODO: Implement or import from vhlab-thirdparty-python when available.
        """
        # TODO: Implement actual SpikeGadgets config reading
        return {
            'samplingRate': '30000',
            'numChannels': '0',
            'headerSize': '0',
            'nTrodes': []
        }, []

    def _read_spikegadgets_trode_channels(self, filename: str, num_channels: Any,
                                         channels: List[int], sampling_rate: float,
                                         header_size: Any, s0: int, s1: int) -> np.ndarray:
        """
        Read SpikeGadgets nTrode channels.

        Args:
            filename: Path to .rec file
            num_channels: Number of channels
            channels: List of channel numbers (0-indexed)
            sampling_rate: Sampling rate
            header_size: Header size
            s0: Start sample
            s1: End sample

        Returns:
            Data array

        Note:
            This is a placeholder for the external read_SpikeGadgets_trodeChannels function.
            TODO: Implement when available.
        """
        # TODO: Implement actual trode channel reading
        return np.array([])

    def _read_spikegadgets_analog_channels(self, filename: str, num_channels: Any,
                                          byteandbit: List[int], sampling_rate: float,
                                          header_size: Any, s0: int, s1: int) -> np.ndarray:
        """
        Read SpikeGadgets analog channels.

        Args:
            filename: Path to .rec file
            num_channels: Number of channels
            byteandbit: List of byte locations
            sampling_rate: Sampling rate
            header_size: Header size
            s0: Start sample
            s1: End sample

        Returns:
            Data array

        Note:
            This is a placeholder for the external read_SpikeGadgets_analogChannels function.
            TODO: Implement when available.
        """
        # TODO: Implement actual analog channel reading
        return np.array([])

    def _read_spikegadgets_digital_channels(self, filename: str, num_channels: Any,
                                           byteandbit: List[List[int]], sampling_rate: float,
                                           header_size: Any, s0: int, s1: int) -> np.ndarray:
        """
        Read SpikeGadgets digital channels.

        Args:
            filename: Path to .rec file
            num_channels: Number of channels
            byteandbit: List of [byte, bit] pairs
            sampling_rate: Sampling rate
            header_size: Header size
            s0: Start sample
            s1: End sample

        Returns:
            Data array

        Note:
            This is a placeholder for the external read_SpikeGadgets_digitalChannels function.
            TODO: Implement when available.
        """
        # TODO: Implement actual digital channel reading
        return np.array([])

    def __repr__(self) -> str:
        """String representation."""
        return f"SpikeGadgets(name='{self.name if hasattr(self, 'name') else ''}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
