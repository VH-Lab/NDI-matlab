"""Convert dataset date information to Crossref format.

This module converts date information from NDI Cloud format to the
Crossref DatabaseDate format, including creation, publication, and update dates.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertDatasetDate.m
"""

from datetime import datetime
from typing import Dict, Any, Tuple


def convert_dataset_date(cloud_dataset: Dict[str, Any]) -> Dict[str, Any]:
    """Convert dataset date information to Crossref DatabaseDate format.

    Extracts date information from the dataset and converts it to the
    Crossref database date structure with creation, publication, and update dates.

    The function parses ISO format timestamps from the cloud dataset and converts
    them to Crossref date format with separate year, month, and day components.

    Args:
        cloud_dataset: Dictionary containing dataset metadata with:
            - createdAt: ISO timestamp string (e.g., '2025-01-15T10:00:00.000Z')
            - updatedAt: ISO timestamp string (e.g., '2025-01-15T11:00:00.000Z')

    Returns:
        Dictionary representing DatabaseDate with:
        - publication_date: Dict with year, month, day, media_type
        - creation_date: Dict with year, month, day, media_type
        - update_date: Dict with year, month, day, media_type

        All dates use media_type='online'

    Note:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertDatasetDate.m

    Example:
        >>> dataset = {
        ...     'createdAt': '2025-01-15T10:00:00.000Z',
        ...     'updatedAt': '2025-01-16T12:00:00.000Z'
        ... }
        >>> result = convert_dataset_date(dataset)
        >>> print(result['creation_date']['year'])
        '2025'
        >>> print(result['creation_date']['month'])
        '01'
        >>> print(result['update_date']['day'])
        '16'
    """
    # Parse publication date from ISO format
    try:
        publication_datetime = datetime.fromisoformat(
            cloud_dataset['createdAt'].replace('Z', '+00:00')
        )
    except (KeyError, ValueError, AttributeError):
        # Fallback to current date if parsing fails
        publication_datetime = datetime.now()

    year_str = str(publication_datetime.year)
    month_str = f'{publication_datetime.month:02d}'
    day_str = f'{publication_datetime.day:02d}'

    # Create publication_date object
    publication_date = {
        'year': year_str,
        'month': month_str,
        'day': day_str,
        'media_type': 'online'
    }

    # Parse creation and update dates
    created_ymd = timestamp_to_year_month_day(cloud_dataset.get('createdAt', ''))
    updated_ymd = timestamp_to_year_month_day(cloud_dataset.get('updatedAt', ''))

    # Create DatabaseDate object
    dataset_date_obj = {
        'publication_date': publication_date,
        'creation_date': {
            'year': str(created_ymd[0]),
            'month': str(created_ymd[1]),
            'day': str(created_ymd[2]),
            'media_type': 'online'
        },
        'update_date': {
            'year': str(updated_ymd[0]),
            'month': str(updated_ymd[1]),
            'day': str(updated_ymd[2]),
            'media_type': 'online'
        }
    }

    return dataset_date_obj


def timestamp_to_year_month_day(timestamp: str) -> Tuple[int, int, int]:
    """Convert ISO timestamp to (year, month, day) tuple.

    Parses an ISO format timestamp string and extracts the date components.

    Args:
        timestamp: ISO format timestamp string (e.g., '2025-01-15T10:00:00.000Z')

    Returns:
        Tuple of (year, month, day) as integers

    Note:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertDatasetDate.m
        (internal function timestampToYearMonthDay)

    Example:
        >>> ymd = timestamp_to_year_month_day('2025-01-15T10:00:00.000Z')
        >>> print(ymd)
        (2025, 1, 15)
    """
    try:
        # Handle ISO format with 'Z' suffix
        datetime_value = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        year = datetime_value.year
        month = datetime_value.month
        day = datetime_value.day
    except (ValueError, AttributeError):
        # Fallback to current date if parsing fails
        now = datetime.now()
        year = now.year
        month = now.month
        day = now.day

    return (year, month, day)


# Object-oriented approach (alternative implementation)

class PublicationDate:
    """Publication date for Crossref.

    Attributes:
        year: Year as string
        month: Month as zero-padded string
        day: Day as zero-padded string
        media_type: Media type (e.g., 'online', 'print')
    """

    def __init__(self, year: str, month: str, day: str, media_type: str = 'online'):
        """Initialize PublicationDate.

        Args:
            year: Year string
            month: Month string (zero-padded)
            day: Day string (zero-padded)
            media_type: Media type string (default: 'online')
        """
        self.year = year
        self.month = month
        self.day = day
        self.media_type = media_type

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with date components
        """
        return {
            'year': self.year,
            'month': self.month,
            'day': self.day,
            'media_type': self.media_type
        }

    @classmethod
    def from_datetime(cls, dt: datetime, media_type: str = 'online') -> 'PublicationDate':
        """Create PublicationDate from datetime object.

        Args:
            dt: datetime object
            media_type: Media type string

        Returns:
            PublicationDate object
        """
        return cls(
            year=str(dt.year),
            month=f'{dt.month:02d}',
            day=f'{dt.day:02d}',
            media_type=media_type
        )


class CreationDate:
    """Creation date for Crossref.

    Attributes:
        year: Year as string
        month: Month as zero-padded string
        day: Day as zero-padded string
        media_type: Media type (e.g., 'online', 'print')
    """

    def __init__(self, year: str, month: str, day: str, media_type: str = 'online'):
        """Initialize CreationDate.

        Args:
            year: Year string
            month: Month string (zero-padded)
            day: Day string (zero-padded)
            media_type: Media type string (default: 'online')
        """
        self.year = year
        self.month = month
        self.day = day
        self.media_type = media_type

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with date components
        """
        return {
            'year': self.year,
            'month': self.month,
            'day': self.day,
            'media_type': self.media_type
        }


class UpdateDate:
    """Update date for Crossref.

    Attributes:
        year: Year as string
        month: Month as zero-padded string
        day: Day as zero-padded string
        media_type: Media type (e.g., 'online', 'print')
    """

    def __init__(self, year: str, month: str, day: str, media_type: str = 'online'):
        """Initialize UpdateDate.

        Args:
            year: Year string
            month: Month string (zero-padded)
            day: Day string (zero-padded)
            media_type: Media type string (default: 'online')
        """
        self.year = year
        self.month = month
        self.day = day
        self.media_type = media_type

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with date components
        """
        return {
            'year': self.year,
            'month': self.month,
            'day': self.day,
            'media_type': self.media_type
        }


class DatabaseDate:
    """Database date information for Crossref.

    Attributes:
        publication_date: PublicationDate object
        creation_date: CreationDate object
        update_date: UpdateDate object
    """

    def __init__(
        self,
        publication_date: PublicationDate,
        creation_date: CreationDate,
        update_date: UpdateDate
    ):
        """Initialize DatabaseDate.

        Args:
            publication_date: PublicationDate object
            creation_date: CreationDate object
            update_date: UpdateDate object
        """
        self.publication_date = publication_date
        self.creation_date = creation_date
        self.update_date = update_date

    def to_dict(self) -> Dict[str, Dict[str, str]]:
        """Convert to dictionary.

        Returns:
            Dictionary with all date fields
        """
        return {
            'publication_date': self.publication_date.to_dict(),
            'creation_date': self.creation_date.to_dict(),
            'update_date': self.update_date.to_dict()
        }


def convert_dataset_date_object(cloud_dataset: Dict[str, Any]) -> DatabaseDate:
    """Convert dataset dates to DatabaseDate object.

    Alternative to convert_dataset_date() that returns a DatabaseDate object
    instead of a dictionary.

    Args:
        cloud_dataset: Cloud dataset dictionary with date fields

    Returns:
        DatabaseDate object

    Example:
        >>> dataset = {'createdAt': '2025-01-15T10:00:00.000Z',
        ...            'updatedAt': '2025-01-16T12:00:00.000Z'}
        >>> db_date = convert_dataset_date_object(dataset)
        >>> print(db_date.creation_date.year)
        '2025'
    """
    date_dict = convert_dataset_date(cloud_dataset)

    publication_date = PublicationDate(
        year=date_dict['publication_date']['year'],
        month=date_dict['publication_date']['month'],
        day=date_dict['publication_date']['day'],
        media_type=date_dict['publication_date']['media_type']
    )

    creation_date = CreationDate(
        year=date_dict['creation_date']['year'],
        month=date_dict['creation_date']['month'],
        day=date_dict['creation_date']['day'],
        media_type=date_dict['creation_date']['media_type']
    )

    update_date = UpdateDate(
        year=date_dict['update_date']['year'],
        month=date_dict['update_date']['month'],
        day=date_dict['update_date']['day'],
        media_type=date_dict['update_date']['media_type']
    )

    database_date = DatabaseDate(
        publication_date=publication_date,
        creation_date=creation_date,
        update_date=update_date
    )

    return database_date
