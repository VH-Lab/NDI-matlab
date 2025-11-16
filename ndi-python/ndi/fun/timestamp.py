"""
Generate UTC timestamps for NDI.

This module provides timestamp generation functionality for NDI documents
and logging.

Ported from MATLAB: src/ndi/+ndi/+fun/timestamp.m
"""

from datetime import datetime, timezone


def timestamp() -> str:
    """
    Return a current UTC timestamp string.

    Returns a current timestamp string in UTC with leap seconds handling.
    The format is ISO 8601 compatible. The string is checked to ensure
    seconds are not "60.000" (which can occur due to rounding and cause
    database validation errors). In that case, seconds are set to "59.999".

    Returns:
        str: UTC timestamp string in ISO format

    Example:
        >>> ts = timestamp()
        >>> print(ts)
        '2025-11-16T12:34:56.789000+00:00'

    Notes:
        - Uses UTC timezone
        - Handles leap second rounding (60.000 -> 59.999)
        - Compatible with database storage
        - ISO 8601 format
    """
    # Get current UTC time
    timestamp_string = datetime.now(timezone.utc).isoformat()

    # Check for and fix the 60.000 seconds issue
    # This can happen due to leap seconds and rounding
    if '60.000' in timestamp_string:
        timestamp_string = timestamp_string.replace('60.000', '59.999')

    return timestamp_string


def timestamp_matlab_format() -> str:
    """
    Return timestamp in MATLAB-compatible format.

    Returns:
        str: Timestamp string matching MATLAB's datetime format

    Example:
        >>> ts = timestamp_matlab_format()
        >>> print(ts)
        '16-Nov-2025 12:34:56'
    """
    # MATLAB format: dd-MMM-yyyy HH:mm:ss
    dt = datetime.now(timezone.utc)
    return dt.strftime('%d-%b-%Y %H:%M:%S')
