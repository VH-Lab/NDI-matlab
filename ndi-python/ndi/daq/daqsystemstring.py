"""
DAQ System String - Parse and generate device strings for DAQ systems.

A device string describes the device and channels that correspond to a DAQ
system epoch probe map. For example:
    'mydevice:ai27-28,45,88' specifies device 'mydevice', analog input,
    channels 27, 28, 45, 88

Ported from MATLAB: src/ndi/+ndi/+daq/daqsystemstring.m
"""

import re
from typing import List, Tuple, Union, Optional


class DAQSystemString:
    """
    DAQ system device string parser and generator.

    A device string indicates the channel types and channel numbers that
    correspond to a particular recording. The format is:
        DEVICENAME:CT####
    where:
        - DEVICENAME is the ndi.daq.system object name
        - CT is the channel type identifier (e.g., 'ai', 'di', 'ao', 'do')
        - #### is a list of channels using:
          - '-' for sequential runs (e.g., '1-5' = [1,2,3,4,5])
          - ',' to separate channels
          - ';' to separate channel types

    Examples:
        >>> # From components
        >>> dss = DAQSystemString('mydevice', ['ai']*7, [1,2,3,4,5,10,17])
        >>> print(dss.devicestring())  # 'mydevice:ai1-5,10,17'

        >>> # From string
        >>> dss = DAQSystemString('mydevice:ai1-5,7,23')
        >>> print(dss.devicename)  # 'mydevice'
        >>> print(dss.channeltype)  # ['ai', 'ai', 'ai', 'ai', 'ai', 'ai', 'ai']
        >>> print(dss.channellist)  # [1, 2, 3, 4, 5, 7, 23]

    Attributes:
        devicename: Name of the device
        channeltype: List of channel type strings for each channel
        channellist: List of channel numbers
    """

    def __init__(
        self,
        devicename: Union[str, None] = None,
        channeltype: Optional[List[str]] = None,
        channellist: Optional[List[int]] = None
    ):
        """
        Initialize DAQSystemString from components or string.

        Args:
            devicename: Either device name or full device string to parse
            channeltype: List of channel types (if devicename is a device name)
            channellist: List of channel numbers (if devicename is a device name)

        If only devicename is provided and it contains ':', it's parsed as a
        device string. Otherwise, all three parameters are required.
        """
        if channeltype is None and channellist is None:
            # Parse from string
            if devicename is None or ':' not in devicename:
                raise ValueError("If parsing from string, devicename must contain ':'")
            self.devicename, self.channeltype, self.channellist = \
                self._parse_devicestring(devicename)
        else:
            # Build from components
            if devicename is None or channeltype is None or channellist is None:
                raise ValueError("devicename, channeltype, and channellist all required")
            self.devicename = devicename
            self.channeltype = channeltype
            self.channellist = channellist

            if len(channeltype) != len(channellist):
                raise ValueError("channeltype and channellist must have same length")

    def _parse_devicestring(self, devstr: str) -> Tuple[str, List[str], List[int]]:
        """
        Parse device string into components.

        Args:
            devstr: Device string like 'mydevice:ai1-5,13,18'

        Returns:
            Tuple of (devicename, channeltype_list, channel_list)
        """
        # Remove whitespace
        devstr = devstr.replace(' ', '')

        # Find colon separator
        if ':' not in devstr:
            raise ValueError(f"Device string must contain ':' separator: {devstr}")

        colon_pos = devstr.index(':')
        devicename = devstr[:colon_pos]

        # Add trailing semicolon if not present for easier parsing
        channel_part = devstr[colon_pos + 1:]
        if not channel_part.endswith(';'):
            channel_part += ';'

        # Parse semicolon-separated segments (different channel types)
        channeltype_list = []
        channel_list = []

        segments = channel_part.split(';')
        for segment in segments:
            if not segment:
                continue

            # Find where numbers start
            match = re.search(r'\d', segment)
            if match is None:
                raise ValueError(f"No numbers found in segment: {segment}")

            first_number_pos = match.start()
            ct = segment[:first_number_pos]
            channel_str = segment[first_number_pos:]

            # Parse channel numbers
            channels = self._parse_channel_sequence(channel_str)

            # Add to lists
            channeltype_list.extend([ct] * len(channels))
            channel_list.extend(channels)

        return devicename, channeltype_list, channel_list

    def _parse_channel_sequence(self, channel_str: str) -> List[int]:
        """
        Parse channel sequence string to list of integers.

        Args:
            channel_str: Channel sequence like '1-5,10,17' or '2,5,11-12,8'

        Returns:
            List of channel numbers

        Examples:
            '1-5,10,17' -> [1, 2, 3, 4, 5, 10, 17]
            '2,5,11-12,8' -> [2, 5, 11, 12, 8]
        """
        channels = []

        # Split by comma
        parts = channel_str.split(',')

        for part in parts:
            if not part:
                continue

            if '-' in part:
                # Range like '1-5'
                start_end = part.split('-')
                if len(start_end) != 2:
                    raise ValueError(f"Invalid range: {part}")
                start = int(start_end[0])
                end = int(start_end[1])
                channels.extend(range(start, end + 1))
            else:
                # Single number
                channels.append(int(part))

        return channels

    def devicestring(self) -> str:
        """
        Generate device string from components.

        Returns:
            Device string like 'mydevice:ai1-5,10,11-23'

        Example:
            >>> dss = DAQSystemString('mydevice', ['ai']*7, [1,2,3,4,5,10,17])
            >>> dss.devicestring()
            'mydevice:ai1-5,10,17'
        """
        devstr = f"{self.devicename}:"

        # Group consecutive channels by channel type
        if not self.channellist:
            return devstr

        prev_channeltype = ''
        new_channellist = []

        for i, (ch_num, ch_type) in enumerate(zip(self.channellist, self.channeltype)):
            if ch_type == prev_channeltype:
                # Same type, add to current list
                new_channellist.append(ch_num)
            else:
                # Different type, write previous list
                if new_channellist:
                    devstr += prev_channeltype
                    devstr += self._format_channel_sequence(new_channellist)
                    devstr += ';'

                # Start new list
                new_channellist = [ch_num]
                prev_channeltype = ch_type

            # Write final segment
            if i == len(self.channellist) - 1:
                devstr += ch_type
                devstr += self._format_channel_sequence(new_channellist)

        return devstr

    def _format_channel_sequence(self, channels: List[int]) -> str:
        """
        Format channel list as compact string with ranges.

        Args:
            channels: List of channel numbers

        Returns:
            Compact string like '1-5,10,17'

        Example:
            [1, 2, 3, 4, 5, 10, 17] -> '1-5,10,17'
        """
        if not channels:
            return ''

        result = []
        i = 0

        while i < len(channels):
            start = channels[i]
            end = start

            # Find consecutive run
            while (i + 1 < len(channels) and
                   channels[i + 1] == channels[i] + 1):
                i += 1
                end = channels[i]

            # Format range or single number
            if end > start + 1:
                # Range of 3+ numbers
                result.append(f"{start}-{end}")
            elif end == start + 1:
                # Two consecutive numbers
                result.append(f"{start}-{end}")
            else:
                # Single number
                result.append(str(start))

            i += 1

        return ','.join(result)

    def __repr__(self) -> str:
        return f"DAQSystemString('{self.devicestring()}')"

    def __str__(self) -> str:
        return self.devicestring()

    def __eq__(self, other) -> bool:
        if not isinstance(other, DAQSystemString):
            return False
        return (self.devicename == other.devicename and
                self.channeltype == other.channeltype and
                self.channellist == other.channellist)
