"""
NDI Datetime Utilities - Helper functions for datetime processing.

This module provides utilities for converting between different datetime
formats used in NDI documents.
"""

from datetime import datetime
from typing import Union
import dateutil.parser


def datestamp2datetime(datestamp_str: str) -> datetime:
    """
    Convert a datestamp string to a datetime object.

    Converts a datestamp string in the format provided by NDI Document
    objects (in base.datestamp) and returns a Python datetime object.

    The input format is assumed to be ISO 8601 with timezone information:
    'yyyy-MM-ddTHH:mm:ss.SSS±HH:MM' (e.g., '2023-01-01T12:00:00.000+00:00')

    The output datetime is always converted to UTC timezone.

    Args:
        datestamp_str: Datestamp string in ISO 8601 format

    Returns:
        datetime object in UTC timezone

    Raises:
        ValueError: If the datestamp string cannot be parsed
        TypeError: If input is not a string

    Examples:
        >>> ds = '2023-01-01T12:00:00.000+00:00'
        >>> dt = datestamp2datetime(ds)
        >>> print(dt)
        2023-01-01 12:00:00+00:00

        >>> # With different timezone (converted to UTC)
        >>> ds = '2023-10-26T15:30:00.123+05:00'  # 5 hours ahead of UTC
        >>> dt = datestamp2datetime(ds)
        >>> print(dt)
        2023-10-26 10:30:00.123000+00:00

    Notes:
        - Input must be a string
        - Timezone information is required in the input
        - Output is always in UTC
        - Milliseconds are preserved
    """
    if not isinstance(datestamp_str, str):
        raise TypeError(f"datestamp_str must be a string, got {type(datestamp_str)}")

    if not datestamp_str:
        raise ValueError("datestamp_str cannot be empty")

    try:
        # Parse the ISO 8601 datetime string with timezone
        dt = dateutil.parser.isoparse(datestamp_str)

        # Convert to UTC if not already
        if dt.tzinfo is not None:
            import pytz
            dt = dt.astimezone(pytz.UTC)
        else:
            # If no timezone, assume UTC
            import pytz
            dt = dt.replace(tzinfo=pytz.UTC)

        return dt

    except (ValueError, AttributeError) as e:
        raise ValueError(f"Cannot parse datestamp string '{datestamp_str}': {e}") from e


def datetime2datestamp(dt: datetime) -> str:
    """
    Convert a datetime object to a datestamp string.

    Converts a Python datetime object to the ISO 8601 format used by
    NDI Document objects.

    Args:
        dt: datetime object (naive or timezone-aware)

    Returns:
        Datestamp string in format 'yyyy-MM-ddTHH:mm:ss.SSS+00:00'

    Examples:
        >>> from datetime import datetime
        >>> import pytz
        >>> dt = datetime(2023, 1, 1, 12, 0, 0, tzinfo=pytz.UTC)
        >>> ds = datetime2datestamp(dt)
        >>> print(ds)
        2023-01-01T12:00:00.000+00:00

    Notes:
        - If datetime is naive (no timezone), UTC is assumed
        - Output is always in UTC
        - Milliseconds are zero-padded to 3 digits
    """
    if not isinstance(dt, datetime):
        raise TypeError(f"dt must be a datetime object, got {type(dt)}")

    # Convert to UTC if timezone-aware
    if dt.tzinfo is not None:
        import pytz
        dt = dt.astimezone(pytz.UTC)
    else:
        # Assume UTC for naive datetimes
        import pytz
        dt = dt.replace(tzinfo=pytz.UTC)

    # Format as ISO 8601 with milliseconds
    # Format: yyyy-MM-ddTHH:mm:ss.SSS+00:00
    milliseconds = dt.microsecond // 1000
    formatted = dt.strftime('%Y-%m-%dT%H:%M:%S')
    formatted += f'.{milliseconds:03d}+00:00'

    return formatted
