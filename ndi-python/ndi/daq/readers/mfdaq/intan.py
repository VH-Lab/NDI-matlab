"""
NDI DAQ Reader MFDAQ Intan - Device driver for Intan Technologies RHD file format.

This class reads data from Intan Technologies .RHD file format.

Intan Technologies: http://intantech.com/
"""

from typing import List, Tuple, Dict, Any, Optional
import re
import os
import numpy as np
from ..mfdaq import MFDAQReader


class Intan(MFDAQReader):
    """
    Intan reader for Intan Technologies RHD/RHS file format.

    This class reads data from Intan Technologies .RHD file format,
    supporting both single-file and directory-based (1-file-per-channel) modes.

    Examples:
        >>> from ndi.daq.reader.mfdaq import Intan
        >>> reader = Intan()
        >>> channels = reader.getchannelsepoch(epochfiles)
    """

    def __init__(self, *args):
        """
        Create a new Intan reader.

        Args:
            *args: Arguments passed to MFDAQReader constructor
        """
        super().__init__(*args)

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        List the channels that are available on this Intan device for a given set of files.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of channel dictionaries with fields:
            - 'name': The name of the channel (e.g., 'ai1')
            - 'type': The type of data stored in the channel
                     (e.g., 'analog_in', 'digital_in', 'auxiliary_in', 'time')
            - 'time_channel': The channel number that contains time information
        """
        channels = []

        # Add time channel first
        channels.append({
            'name': 't1',
            'type': 'time',
            'time_channel': 1
        })

        # Intan channel types in header
        intan_channel_types = [
            'amplifier_channels',
            'aux_input_channels',
            'board_dig_in_channels',
            'board_dig_out_channels'
        ]

        # Open RHD file and examine header for all channels present
        filename = self.filenamefromepochfiles(epochfiles)
        header = self._read_intan_header(filename)

        for intan_type in intan_channel_types:
            if intan_type in header:
                # Convert Intan type to MFDAQ type
                mfdaq_type = self.intanheadertype2mfdaqchanneltype(intan_type)

                intan_channels = header[intan_type]
                for ch in intan_channels:
                    # Convert Intan name to MFDAQ name
                    name = self.intanname2mfdaqname(mfdaq_type, ch['native_channel_name'])

                    time_channel = 1
                    if mfdaq_type == 'auxiliary_in':
                        time_channel = 2

                    channels.append({
                        'name': name,
                        'type': mfdaq_type,
                        'time_channel': time_channel
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

    def filenamefromepochfiles(self, filename_array: List[str]) -> Tuple[str, str, bool]:
        """
        Return the file name that corresponds to the RHD file, or directory in case of directory mode.

        Args:
            filename_array: List of full path file strings

        Returns:
            Tuple of (filename, parentdir, isdirectory) where:
            - filename: The RHD file path
            - parentdir: Parent directory if directory mode
            - isdirectory: True if using 1-file-per-channel mode

        Raises:
            ValueError: If no .rhd file found or multiple .rhd files found
        """
        # Look for .rhd files
        rhd_pattern = r'.*\.rhd$'
        matching_files = []

        for filepath in filename_array:
            if re.search(rhd_pattern, filepath, re.IGNORECASE):
                matching_files.append(filepath)

        if len(matching_files) > 1:
            raise ValueError('Need only 1 .rhd file per epoch.')
        elif len(matching_files) == 0:
            raise ValueError('Need 1 .rhd file per epoch.')

        filename = matching_files[0]
        parentdir, fname_with_ext = os.path.split(filename)
        fname, ext = os.path.splitext(fname_with_ext)

        isdirectory = False

        # Check if this is directory mode (info.rhd + time.dat)
        if 'info' in fname:
            # Look for time.dat file
            time_dat_pattern = r'time\.dat$'
            for filepath in filename_array:
                if re.search(time_dat_pattern, filepath, re.IGNORECASE):
                    isdirectory = True
                    break

        return filename, parentdir, isdirectory

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
        filename, parentdir, isdirectory = self.filenamefromepochfiles(epochfiles)

        # Ensure channeltype is a list
        if not isinstance(channeltype, list):
            channeltype = [channeltype] * len(channel)

        # Check that all channels are the same type
        unique_types = list(set(channeltype))
        if len(unique_types) != 1:
            raise ValueError('Only one type of channel may be read per function call at present.')

        intan_channeltype = self.mfdaqchanneltype2intanchanneltype(unique_types[0])

        # Get sample rates
        sr = self.samplerate(epochfiles, channeltype, channel)
        sr_unique = list(set(sr))
        if len(sr_unique) != 1:
            raise ValueError('Do not know how to handle different sampling rates across channels.')

        sr_val = sr_unique[0]

        # Convert samples to time
        t0 = (s0 - 1) / sr_val
        t1 = (s1 - 1) / sr_val

        # Handle special channel types
        channel_to_read = channel.copy()
        alt_channel = None
        is_digital = False

        if intan_channeltype == 'time':
            channel_to_read = [1]  # Time only has 1 channel in Intan RHD
        elif intan_channeltype == 'din':
            is_digital = True
            alt_channel = channel
            channel_to_read = [1]
        elif intan_channeltype == 'dout':
            is_digital = True
            alt_channel = channel
            channel_to_read = [1]

        # Read data from file
        if not isdirectory:
            data = self._read_intan_datafile(filename, intan_channeltype, channel_to_read, t0, t1)
        else:
            data = self._read_intan_directory(parentdir, intan_channeltype, channel_to_read, t0, t1)

        # Handle digital channels - extract specific bits
        if is_digital and alt_channel is not None:
            # Convert to binary representation
            digital_data = self._int2bit(data, 8)

            # Ensure 16 bits wide
            if digital_data.shape[1] < 16:
                digital_data = np.concatenate([
                    digital_data,
                    np.zeros((digital_data.shape[0], 8), dtype=int)
                ], axis=1)

            # Extract requested channels
            data = digital_data[:, alt_channel]

        return data

    def underlying_datatype(self, epochfiles: List[str], channeltype: str,
                           channel: List[int]) -> Tuple[str, List[float], int]:
        """
        Get the underlying data type for a channel in an epoch.

        Args:
            epochfiles: List of file paths for this epoch
            channeltype: Type of channel (string)
            channel: List of channel numbers

        Returns:
            Tuple of (datatype, polynomial, datasize) where:
            - datatype: Type suitable for fread/fwrite (e.g., 'uint16', 'float64')
            - polynomial: Conversion polynomial [offset, scale]
            - datasize: Sample size in bits
        """
        if channeltype in ['analog_in', 'analog_out']:
            datatype = 'uint16'
            datasize = 16
            p = [32768, 0.195]
        elif channeltype == 'auxiliary_in':
            datatype = 'uint16'
            datasize = 16
            p = [0, 3.7400e-05]
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
        filename, _, _ = self.filenamefromepochfiles(epochfiles)

        # Ensure channeltype is a list
        if not isinstance(channeltype, list):
            if len(channel) > 1:
                channeltype = [channeltype] * len(channel)
            else:
                channeltype = [channeltype]

        # Read header
        header = self._read_intan_header(filename)

        sr = []
        for i, ch in enumerate(channel):
            ct = channeltype[i] if isinstance(channeltype, list) else channeltype
            freq_fieldname = self.mfdaqchanneltype2intanfreqheader(ct)
            sr.append(header['frequency_parameters'][freq_fieldname])

        return sr

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """
        Return the t0_t1 (beginning and end) epoch times for an epoch.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List containing [t0, t1] pair in seconds
        """
        filename, parentdir, isdirectory = self.filenamefromepochfiles(epochfiles)
        header = self._read_intan_header(filename)

        if not isdirectory:
            # Read block info to get total samples
            total_samples = self._get_intan_total_samples_file(filename, header)
        else:
            # Read from time.dat file
            time_dat_path = os.path.join(parentdir, 'time.dat')
            if not os.path.isfile(time_dat_path):
                raise ValueError(f'File time.dat necessary in directory {parentdir} but it was not found.')

            file_size = os.path.getsize(time_dat_path)
            total_samples = file_size // 4  # 4 bytes per sample (int32)

        # Calculate total time
        total_time = total_samples / header['frequency_parameters']['amplifier_sample_rate']

        t0 = 0
        t1 = total_time - 1 / header['frequency_parameters']['amplifier_sample_rate']

        return [[t0, t1]]

    # Static helper methods

    @staticmethod
    def mfdaqchanneltype2intanheadertype(channeltype: str) -> str:
        """
        Convert between the ndi.daq.reader.mfdaq channel types and Intan headers.

        Args:
            channeltype: MFDAQ channel type

        Returns:
            Intan header type name
        """
        conversion = {
            'analog_in': 'amplifier_channels',
            'ai': 'amplifier_channels',
            'digital_in': 'board_dig_in_channels',
            'di': 'board_dig_in_channels',
            'digital_out': 'board_dig_out_channels',
            'do': 'board_dig_out_channels',
            'auxiliary': 'aux_input_channels',
            'aux': 'aux_input_channels',
            'ax': 'aux_input_channels',
            'auxiliary_in': 'aux_input_channels',
            'auxiliary_input': 'aux_input_channels'
        }

        if channeltype not in conversion:
            raise ValueError(f'Could not convert channeltype {channeltype}.')

        return conversion[channeltype]

    @staticmethod
    def intanheadertype2mfdaqchanneltype(intanchanneltype: str) -> str:
        """
        Convert between Intan headers and the ndi.daq.reader.mfdaq channel types.

        Args:
            intanchanneltype: Intan header type

        Returns:
            MFDAQ channel type
        """
        conversion = {
            'amplifier_channels': 'analog_in',
            'board_dig_in_channels': 'digital_in',
            'board_dig_out_channels': 'digital_out',
            'aux_input_channels': 'auxiliary_in'
        }

        if intanchanneltype not in conversion:
            raise ValueError(f'Could not convert channeltype {intanchanneltype}.')

        return conversion[intanchanneltype]

    @staticmethod
    def mfdaqchanneltype2intanchanneltype(channeltype: str) -> str:
        """
        Convert the channel type from generic MFDAQ format to specific Intan channel type.

        Args:
            channeltype: MFDAQ channel type

        Returns:
            Intan-specific channel type string
        """
        conversion = {
            'analog_in': 'amp',
            'ai': 'amp',
            'digital_in': 'din',
            'di': 'din',
            'digital_out': 'dout',
            'do': 'dout',
            'time': 'time',
            'timestamp': 'time',
            'auxiliary': 'aux',
            'aux': 'aux',
            'auxiliary_input': 'aux',
            'auxiliary_in': 'aux'
        }

        if channeltype not in conversion:
            raise ValueError(f'Do not know how to convert channel type {channeltype}.')

        return conversion[channeltype]

    @staticmethod
    def intanname2mfdaqname(mfdaq_type: str, name: str) -> str:
        """
        Convert a channel name from Intan native format to ndi.daq.reader.mfdaq format.

        Args:
            mfdaq_type: MFDAQ channel type string
            name: Intan native channel name (e.g., 'A-000', 'A-AUX1')

        Returns:
            MFDAQ channel name (e.g., 'ai1', 'ax1')
        """
        # Find separator
        sep_idx = name.find('-')
        if sep_idx == -1:
            raise ValueError(f'Cannot parse Intan channel name: {name}')

        # Check if aux channel
        isaux = False
        if len(name) >= sep_idx + 4:
            if name[sep_idx+1:sep_idx+4].upper() == 'AUX':
                sep_idx = sep_idx + 3
                isaux = True

        # Extract channel number
        chan_str = name[sep_idx+1:]
        try:
            chan_intan = int(chan_str)
        except ValueError:
            raise ValueError(f'Cannot parse channel number from: {name}')

        # Intan numbers from 0, NDI from 1
        if not isaux:
            chan = chan_intan + 1
        else:
            chan = chan_intan

        # Get MFDAQ prefix
        from ...system.mfdaq import MFDAQSystem
        prefix = MFDAQSystem.mfdaq_prefix(mfdaq_type)

        return f'{prefix}{chan}'

    @staticmethod
    def mfdaqchanneltype2intanfreqheader(channeltype: str) -> str:
        """
        Return header name with frequency information for channel type.

        Args:
            channeltype: MFDAQ channel type

        Returns:
            Frequency header field name
        """
        conversion = {
            'analog_in': 'amplifier_sample_rate',
            'ai': 'amplifier_sample_rate',
            'digital_in': 'board_dig_in_sample_rate',
            'di': 'board_dig_in_sample_rate',
            'digital_out': 'board_dig_out_sample_rate',
            'do': 'board_dig_out_sample_rate',
            'time': 'amplifier_sample_rate',
            'timestamp': 'amplifier_sample_rate',
            'auxiliary': 'aux_input_sample_rate',
            'aux': 'aux_input_sample_rate',
            'auxiliary_in': 'aux_input_sample_rate'
        }

        if channeltype not in conversion:
            raise ValueError(f'Do not know frequency header name for channel type {channeltype}.')

        return conversion[channeltype]

    # Private helper methods for file I/O (placeholders for external dependencies)

    def _read_intan_header(self, filename: str) -> Dict[str, Any]:
        """
        Read Intan RHD2000 header.

        Args:
            filename: Path to RHD file

        Returns:
            Header dictionary

        Note:
            This is a placeholder for the external read_Intan_RHD2000_header function.
            TODO: Implement or import from vhlab-thirdparty-python when available.
        """
        # TODO: Implement actual Intan header reading
        # For now, return minimal structure
        return {
            'frequency_parameters': {
                'amplifier_sample_rate': 20000.0,
                'aux_input_sample_rate': 20000.0,
                'board_dig_in_sample_rate': 20000.0,
                'board_dig_out_sample_rate': 20000.0
            },
            'amplifier_channels': [],
            'aux_input_channels': [],
            'board_dig_in_channels': [],
            'board_dig_out_channels': []
        }

    def _read_intan_datafile(self, filename: str, channeltype: str,
                            channels: List[int], t0: float, t1: float) -> np.ndarray:
        """
        Read Intan RHD2000 data file.

        Args:
            filename: Path to RHD file
            channeltype: Intan channel type
            channels: List of channel numbers
            t0: Start time in seconds
            t1: End time in seconds

        Returns:
            Data array

        Note:
            This is a placeholder for the external read_Intan_RHD2000_datafile function.
            TODO: Implement or import from vhlab-thirdparty-python when available.
        """
        # TODO: Implement actual Intan data reading
        return np.array([])

    def _read_intan_directory(self, parentdir: str, channeltype: str,
                             channels: List[int], t0: float, t1: float) -> np.ndarray:
        """
        Read Intan RHD2000 directory (1-file-per-channel mode).

        Args:
            parentdir: Directory containing data files
            channeltype: Intan channel type
            channels: List of channel numbers
            t0: Start time in seconds
            t1: End time in seconds

        Returns:
            Data array

        Note:
            This is a placeholder for the external read_Intan_RHD2000_directory function.
            TODO: Implement or import from vhlab-thirdparty-python when available.
        """
        # TODO: Implement actual Intan directory reading
        return np.array([])

    def _get_intan_total_samples_file(self, filename: str, header: Dict[str, Any]) -> int:
        """
        Get total samples from Intan file.

        Args:
            filename: Path to RHD file
            header: Intan header dictionary

        Returns:
            Total number of samples

        Note:
            This is a placeholder for block info calculation.
            TODO: Implement based on Intan_RHD2000_blockinfo when available.
        """
        # TODO: Implement actual block info reading
        # For now, return 0
        return 0

    @staticmethod
    def _int2bit(data: np.ndarray, nbits: int) -> np.ndarray:
        """
        Convert integer array to binary representation.

        Args:
            data: Integer data array
            nbits: Number of bits

        Returns:
            Binary representation (each row is one value, columns are bits)
        """
        # Flatten if needed
        original_shape = data.shape
        data_flat = data.flatten()

        # Convert to binary
        binary = np.zeros((len(data_flat), nbits), dtype=int)
        for i, val in enumerate(data_flat):
            binary[i] = [(int(val) >> bit) & 1 for bit in range(nbits)]

        # Reshape if needed
        if len(original_shape) > 1:
            binary = binary.reshape(original_shape[0], original_shape[1], nbits)

        return binary

    def __repr__(self) -> str:
        """String representation."""
        return f"Intan(name='{self.name if hasattr(self, 'name') else ''}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
