"""
Parse channel names into prefix and number components.

Ported from MATLAB: src/ndi/+ndi/+fun/channelname2prefixnumber.m
"""

import re
from typing import Tuple


def channelname2prefixnumber(channel_name: str) -> Tuple[str, int]:
    """
    Parse a channel name into prefix and number components.

    Extracts the alphabetic prefix and numeric suffix from channel names
    like 'ch1', 'channel12', 'probe_3', etc.

    Args:
        channel_name: Channel name string (e.g., 'ch1', 'probe_12')

    Returns:
        Tuple of (prefix, number) where prefix is the string part and
        number is the integer part

    Raises:
        ValueError: If channel name doesn't contain a number

    Example:
        >>> prefix, num = channelname2prefixnumber('ch42')
        >>> print(f"Prefix: {prefix}, Number: {num}")
        Prefix: ch, Number: 42
        >>> prefix, num = channelname2prefixnumber('probe_7')
        >>> print(f"Prefix: {prefix}, Number: {num}")
        Prefix: probe_, Number: 7
    """
    # Match pattern: any non-digit characters followed by digits
    match = re.match(r'^([^\d]*)(\d+)$', channel_name)

    if not match:
        raise ValueError(
            f"Channel name '{channel_name}' must contain a number. "
            f"Expected format: 'prefix123' or 'prefix_123'"
        )

    prefix = match.group(1)
    number = int(match.group(2))

    return prefix, number


def prefixnumber2channelname(prefix: str, number: int) -> str:
    """
    Construct a channel name from prefix and number.

    Args:
        prefix: String prefix (e.g., 'ch', 'probe_')
        number: Channel number

    Returns:
        Channel name string

    Example:
        >>> name = prefixnumber2channelname('ch', 42)
        >>> print(name)
        ch42
    """
    return f"{prefix}{number}"
