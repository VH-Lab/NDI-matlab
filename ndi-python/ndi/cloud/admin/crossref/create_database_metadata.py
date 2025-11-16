"""Create database metadata for NDI Cloud Crossref submission.

This module creates the database-level metadata required for Crossref
submissions, including database title, description, organization, dates, and DOI.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/createDatabaseMetadata.m
"""

from typing import Dict, Any, List

from ndi.cloud.admin.crossref.constants import Constants


def create_database_metadata() -> Dict[str, Any]:
    """Create database metadata for NDI Cloud.

    Constructs the complete database metadata structure including:
    - Titles: Database title
    - Description: Database description
    - Contributors: Organization information
    - DatabaseDate: Creation and publication dates
    - DoiData: Database DOI and URL
    - Language: Database language (English)

    Returns:
        Dictionary structure representing database metadata with keys:
        - titles: Database title information
        - description: Database description text
        - contributors: List of organization contributors
        - database_date: Creation and publication dates
        - doi_data: DOI and resource URL
        - language: Language code ('en')

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/+crossref/createDatabaseMetadata.m

    Example:
        >>> metadata = create_database_metadata()
        >>> print(metadata['titles']['title'])
        'NDI Cloud Open Datasets'
        >>> print(metadata['doi_data']['doi'])
        '10.63884/ndic.00000'
    """
    # Create titles object
    database_title = {
        'title': Constants.DATABASE_TITLE
    }

    # Create database_organization object
    database_contributor = {
        'name': Constants.DATABASE_ORGANIZATION,
        'sequence': 'first'
    }

    # Create database_date object
    creation_date_parts = Constants.DATABASE_CREATION_DATE
    creation_date = {
        'year': creation_date_parts[0],
        'month': creation_date_parts[1],
        'day': creation_date_parts[2],
        'media_type': 'online'
    }

    publication_date = {
        'year': creation_date_parts[0],
        'month': creation_date_parts[1],
        'day': creation_date_parts[2],
        'media_type': 'online'
    }

    database_date = {
        'creation_date': creation_date,
        'publication_date': publication_date
    }

    # Create doi_data object
    doi_data = {
        'doi': Constants.DATABASE_DOI,
        'resource': Constants.DATABASE_URL
    }

    # Create database_metadata object
    database_metadata = {
        'titles': database_title,
        'description': Constants.DATABASE_DESCRIPTION,
        'contributors': {
            'items': [database_contributor]
        },
        'database_date': database_date,
        'doi_data': doi_data,
        'language': 'en'
    }

    return database_metadata


# Object-oriented approach (alternative implementation)

class Titles:
    """Titles element for Crossref metadata.

    Attributes:
        title: The main title
    """

    def __init__(self, title: str):
        """Initialize Titles.

        Args:
            title: The title text
        """
        self.title = title

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with title
        """
        return {'title': self.title}


class Organization:
    """Organization contributor for database metadata.

    Attributes:
        name: Organization name
        sequence: Sequence indicator ('first' or 'additional')
    """

    def __init__(self, name: str, sequence: str):
        """Initialize Organization.

        Args:
            name: Organization name
            sequence: Sequence ('first' or 'additional')
        """
        self.name = name
        self.sequence = sequence

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with name and sequence
        """
        return {
            'name': self.name,
            'sequence': self.sequence
        }


class CreationDate:
    """Creation date for database.

    Attributes:
        year: Year as string
        month: Month as string (zero-padded)
        day: Day as string (zero-padded)
        media_type: Media type ('online', 'print', etc.)
    """

    def __init__(self, year: str, month: str, day: str, media_type: str):
        """Initialize CreationDate.

        Args:
            year: Year string
            month: Month string
            day: Day string
            media_type: Media type string
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


class PublicationDate:
    """Publication date for database.

    Attributes:
        year: Year as string
        month: Month as string (zero-padded)
        day: Day as string (zero-padded)
        media_type: Media type ('online', 'print', etc.)
    """

    def __init__(self, year: str, month: str, day: str, media_type: str):
        """Initialize PublicationDate.

        Args:
            year: Year string
            month: Month string
            day: Day string
            media_type: Media type string
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
    """Database date information.

    Attributes:
        creation_date: CreationDate object
        publication_date: PublicationDate object
    """

    def __init__(self, creation_date: CreationDate, publication_date: PublicationDate):
        """Initialize DatabaseDate.

        Args:
            creation_date: Creation date
            publication_date: Publication date
        """
        self.creation_date = creation_date
        self.publication_date = publication_date

    def to_dict(self) -> Dict[str, Dict[str, str]]:
        """Convert to dictionary.

        Returns:
            Dictionary with creation_date and publication_date
        """
        return {
            'creation_date': self.creation_date.to_dict(),
            'publication_date': self.publication_date.to_dict()
        }


class DoiData:
    """DOI data for database.

    Attributes:
        doi: DOI string
        resource: Resource URL
    """

    def __init__(self, doi: str, resource: str):
        """Initialize DoiData.

        Args:
            doi: DOI string
            resource: Resource URL
        """
        self.doi = doi
        self.resource = resource

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with doi and resource
        """
        return {
            'doi': self.doi,
            'resource': self.resource
        }


class Contributors:
    """Contributors collection.

    Attributes:
        items: List of contributor objects
    """

    def __init__(self, items: List[Organization]):
        """Initialize Contributors.

        Args:
            items: List of Organization objects
        """
        self.items = items

    def to_dict(self) -> Dict[str, List[Dict[str, str]]]:
        """Convert to dictionary.

        Returns:
            Dictionary with items list
        """
        return {
            'items': [item.to_dict() for item in self.items]
        }


class DatabaseMetadata:
    """Complete database metadata.

    Attributes:
        titles: Titles object
        description: Description text
        contributors: Contributors object
        database_date: DatabaseDate object
        doi_data: DoiData object
        language: Language code
    """

    def __init__(
        self,
        titles: Titles,
        description: str,
        contributors: Contributors,
        database_date: DatabaseDate,
        doi_data: DoiData,
        language: str
    ):
        """Initialize DatabaseMetadata.

        Args:
            titles: Titles object
            description: Description text
            contributors: Contributors object
            database_date: DatabaseDate object
            doi_data: DoiData object
            language: Language code
        """
        self.titles = titles
        self.description = description
        self.contributors = contributors
        self.database_date = database_date
        self.doi_data = doi_data
        self.language = language

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary.

        Returns:
            Complete metadata dictionary
        """
        return {
            'titles': self.titles.to_dict(),
            'description': self.description,
            'contributors': self.contributors.to_dict(),
            'database_date': self.database_date.to_dict(),
            'doi_data': self.doi_data.to_dict(),
            'language': self.language
        }


def create_database_metadata_object() -> DatabaseMetadata:
    """Create database metadata as a DatabaseMetadata object.

    Alternative to create_database_metadata() that returns an object
    instead of a dictionary.

    Returns:
        DatabaseMetadata object

    Example:
        >>> metadata = create_database_metadata_object()
        >>> print(metadata.titles.title)
        'NDI Cloud Open Datasets'
    """
    # Create titles object
    database_title = Titles(title=Constants.DATABASE_TITLE)

    # Create database_organization object
    database_contributor = Organization(
        name=Constants.DATABASE_ORGANIZATION,
        sequence='first'
    )

    # Create database_date object
    creation_date_parts = Constants.DATABASE_CREATION_DATE
    creation_date = CreationDate(
        year=creation_date_parts[0],
        month=creation_date_parts[1],
        day=creation_date_parts[2],
        media_type='online'
    )

    publication_date = PublicationDate(
        year=creation_date_parts[0],
        month=creation_date_parts[1],
        day=creation_date_parts[2],
        media_type='online'
    )

    database_date = DatabaseDate(
        creation_date=creation_date,
        publication_date=publication_date
    )

    # Create doi_data object
    doi_data = DoiData(
        doi=Constants.DATABASE_DOI,
        resource=Constants.DATABASE_URL
    )

    # Create database_metadata object
    database_metadata = DatabaseMetadata(
        titles=database_title,
        description=Constants.DATABASE_DESCRIPTION,
        contributors=Contributors(items=[database_contributor]),
        database_date=database_date,
        doi_data=doi_data,
        language='en'
    )

    return database_metadata
