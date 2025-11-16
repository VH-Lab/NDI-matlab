"""
NDR Reader - Allows NDI to use NDR format readers.

MATLAB source: ndi/+ndi/+daq/+reader/+mfdaq/ndr.m

This module provides integration with the NDR (NeuroData Repository) format
readers. Requires external NDR-Python library to be installed.

External Dependency: NDR-Python (https://github.com/VH-Lab/NDR-python/)
"""

from typing import List, Dict, Any, Optional, Union
import warnings
from ndi.daq.readers.mfdaq import MFDAQReader


class NDR(MFDAQReader):
    """
    NDR format reader for multi-function DAQ systems.

    MATLAB equivalent: ndi.daq.reader.mfdaq.ndr

    This class reads data using NDR (NeuroData Repository) reader objects.
    It wraps the external NDR library to provide access to various
    neuroscience data formats.

    Supported Formats (via NDR):
        - RHD: Intan RHD format
        - SEV: Tucker-Davis Technologies SEV format
        - SOM: SpikeGadgets format
        - And many others (see ndr.known_readers())

    External Dependency:
        Requires NDR-Python library: https://github.com/VH-Lab/NDR-python/

    Attributes:
        ndr_reader_string: String specifying file type ('RHD', 'sev', etc.)

    Example:
        >>> try:
        ...     reader = NDR('RHD')
        ...     channels = reader.getchannelsepoch(epochfiles)
        ... except ImportError:
        ...     print("NDR library not installed")

    Note:
        Current Status: PLACEHOLDER - Requires external NDR-Python library

        This is a wrapper around the external NDR library. The NDR project
        provides readers for many neuroscience data formats but is maintained
        separately from NDI.

        To use this reader:
        1. Install NDR-Python: pip install ndr-python (when available)
        2. Or use MATLAB version: https://github.com/VH-Lab/NDR-matlab/
    """

    def __init__(self, reader_string: str = 'RHD'):
        """
        Create a new NDR reader.

        Args:
            reader_string: File type string ('RHD', 'sev', 'som', etc.)
                          See ndr.known_readers() for valid options

        Raises:
            ImportError: If NDR library is not available
            ValueError: If reader_string is not a known reader type
        """
        super().__init__()

        if not reader_string:
            raise ValueError("reader_string must not be empty")

        # Try to import NDR library
        try:
            import ndr
            self._ndr_available = True
            self._ndr = ndr
        except ImportError:
            self._ndr_available = False
            self._ndr = None
            warnings.warn(
                "NDR library not available. "
                "Install from: https://github.com/VH-Lab/NDR-python/ "
                "This reader will not be functional without NDR library.",
                UserWarning,
                stacklevel=2
            )

        self.ndr_reader_string = reader_string

        # Validate reader string if NDR is available
        if self._ndr_available:
            known = self._get_known_readers()
            if reader_string not in known:
                raise ValueError(
                    f"reader_string '{reader_string}' not in known readers. "
                    f"Valid options: {', '.join(known)}"
                )

    def getchannelsepoch(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        List channels available for this epoch.

        MATLAB equivalent: getchannelsepoch()

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of channel dictionaries with keys:
                - 'name': Channel name (e.g., 'ai1')
                - 'type': Data type ('analogin', 'digitalin', 'image', 'timestamp')
                - 'time_channel': Channel number with time information

        Raises:
            ImportError: If NDR library is not available
            RuntimeError: If NDR reader fails

        Example:
            >>> channels = reader.getchannelsepoch(['/path/to/file.rhd'])
            >>> for ch in channels:
            ...     print(f"{ch['name']}: {ch['type']}")
        """
        self._check_ndr_available()

        try:
            ndr_reader = self._ndr.reader(self.ndr_reader_string)
            channels = ndr_reader.getchannelsepoch(epochfiles, epoch_number=1)
            return channels
        except Exception as e:
            raise RuntimeError(f"NDR reader failed: {e}") from e

    def readchannels_epochsamples(
        self,
        channeltype: Union[str, List[str]],
        channel: List[int],
        epochfiles: List[str],
        s0: int,
        s1: int
    ) -> Any:
        """
        Read channel data for specified sample range.

        MATLAB equivalent: readchannels_epochsamples()

        Args:
            channeltype: Channel type(s) - string or list of strings
            channel: List of channel numbers (1-indexed)
            epochfiles: List of file paths for this epoch
            s0: Start sample index
            s1: End sample index

        Returns:
            Channel data array (columns = channels)

        Raises:
            ImportError: If NDR library is not available
            RuntimeError: If NDR reader fails

        Example:
            >>> data = reader.readchannels_epochsamples(
            ...     'analogin', [1, 2], epochfiles, 0, 1000
            ... )
        """
        self._check_ndr_available()

        try:
            ndr_reader = self._ndr.reader(self.ndr_reader_string)
            data = ndr_reader.readchannels_epochsamples(
                channeltype, channel, epochfiles,
                epoch_number=1, s0=s0, s1=s1
            )
            return data
        except Exception as e:
            raise RuntimeError(f"NDR reader failed: {e}") from e

    def epochclock(self, epochfiles: List[str]) -> List:
        """
        Return clock types available for this epoch.

        MATLAB equivalent: epochclock()

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of ndi.time.clocktype objects

        Raises:
            ImportError: If NDR library is not available

        Example:
            >>> clocks = reader.epochclock(epochfiles)
            >>> for clock in clocks:
            ...     print(f"Clock: {clock}")
        """
        self._check_ndr_available()

        try:
            ndr_reader = self._ndr.reader(self.ndr_reader_string)
            # NDR readers should provide clock information
            # For now, return default clock
            from ndi.time.clocktype import ClockType
            return [ClockType('utc', 1.0)]
        except Exception as e:
            raise RuntimeError(f"NDR reader failed: {e}") from e

    def samplerate(
        self,
        epochfiles: List[str],
        channeltype: str,
        channel: int
    ) -> float:
        """
        Get sample rate for a channel.

        MATLAB equivalent: samplerate()

        Args:
            epochfiles: List of file paths for this epoch
            channeltype: Channel type string
            channel: Channel number (1-indexed)

        Returns:
            Sample rate in Hz

        Raises:
            ImportError: If NDR library is not available

        Example:
            >>> sr = reader.samplerate(epochfiles, 'analogin', 1)
            >>> print(f"Sample rate: {sr} Hz")
        """
        self._check_ndr_available()

        try:
            ndr_reader = self._ndr.reader(self.ndr_reader_string)
            sr = ndr_reader.samplerate(
                epochfiles, epoch_number=1,
                channeltype=channeltype, channel=channel
            )
            return float(sr)
        except Exception as e:
            raise RuntimeError(f"NDR reader failed: {e}") from e

    @classmethod
    def known_readers(cls) -> List[str]:
        """
        Get list of known NDR reader types.

        Returns:
            List of reader type strings ('RHD', 'sev', etc.)

        Raises:
            ImportError: If NDR library is not available

        Example:
            >>> readers = NDR.known_readers()
            >>> print(f"Available readers: {', '.join(readers)}")
        """
        try:
            import ndr
            return ndr.known_readers()
        except ImportError:
            # Return common reader types as fallback
            return ['RHD', 'sev', 'som', 'ncs', 'plx']

    def _get_known_readers(self) -> List[str]:
        """Get known readers (internal helper)."""
        if self._ndr_available:
            return self._ndr.known_readers()
        else:
            return self.known_readers()

    def _check_ndr_available(self):
        """Check if NDR library is available, raise if not."""
        if not self._ndr_available:
            raise ImportError(
                "NDR library is required for NDR reader functionality. "
                "Install from: https://github.com/VH-Lab/NDR-python/ "
                "Or install MATLAB version: https://github.com/VH-Lab/NDR-matlab/"
            )

    def __repr__(self) -> str:
        """String representation."""
        return f"NDR(reader_string='{self.ndr_reader_string}')"
