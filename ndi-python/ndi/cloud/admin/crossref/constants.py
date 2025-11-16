"""Constants for Crossref DOI registration.

This module defines constants used for Crossref submissions, including DOI prefixes,
database metadata, and URLs for the NDI Cloud system.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/Constants.m
"""

from typing import Tuple


class Constants:
    """Constants for Crossref DOI registration and NDI Cloud database metadata.

    This class contains configuration values used throughout the DOI registration
    process, including the DOI prefix, database information, and URLs.

    Attributes:
        DOI_PREFIX: The DOI prefix assigned to NDI Cloud (10.63884)
        DATABASE_URL: The main URL for NDI Cloud
        DATABASE_DOI: The DOI for the NDI Cloud database itself
        DATABASE_TITLE: The official title of the NDI Cloud database
        DATABASE_DESCRIPTION: Description of the database for Crossref
        DATABASE_ORGANIZATION: The organization operating the database
        DATABASE_CREATION_DATE: Tuple of (year, month, day) when database was created
        NDI_DATASET_BASE_URL: Base URL for individual dataset pages

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/+crossref/Constants.m

    Example:
        >>> from ndi.cloud.admin.crossref.constants import Constants
        >>> print(Constants.DOI_PREFIX)
        '10.63884'
        >>> print(Constants.DATABASE_DOI)
        '10.63884/ndic.00000'
    """

    # DOI prefix assigned to NDI Cloud
    DOI_PREFIX: str = "10.63884"

    # Database URLs
    DATABASE_URL: str = "https://ndi-cloud.com"
    NDI_DATASET_BASE_URL: str = "https://www.ndi-cloud.com/datasets/"

    # Database DOI (using the prefix with a special suffix for the database itself)
    DATABASE_DOI: str = f"{DOI_PREFIX}/ndic.00000"

    # Database metadata
    DATABASE_TITLE: str = "NDI Cloud Open Datasets"
    DATABASE_DESCRIPTION: str = (
        "Searchable scientific datasets from neuroscience and other disciplines"
    )
    DATABASE_ORGANIZATION: str = "Waltham Data Science LLC"

    # Database creation date (year, month, day)
    DATABASE_CREATION_DATE: Tuple[str, str, str] = ("2024", "04", "08")

    @classmethod
    def get_database_creation_date_dict(cls) -> dict:
        """Get database creation date as a dictionary.

        Returns:
            Dictionary with 'year', 'month', 'day' keys

        Example:
            >>> date_dict = Constants.get_database_creation_date_dict()
            >>> print(date_dict)
            {'year': '2024', 'month': '04', 'day': '08'}
        """
        return {
            'year': cls.DATABASE_CREATION_DATE[0],
            'month': cls.DATABASE_CREATION_DATE[1],
            'day': cls.DATABASE_CREATION_DATE[2]
        }

    @classmethod
    def get_dataset_url(cls, dataset_id: str) -> str:
        """Get the full URL for a specific dataset.

        Args:
            dataset_id: The unique identifier for the dataset

        Returns:
            The complete URL to access the dataset

        Example:
            >>> url = Constants.get_dataset_url('abc123')
            >>> print(url)
            'https://www.ndi-cloud.com/datasets/abc123'
        """
        return f"{cls.NDI_DATASET_BASE_URL}{dataset_id}"
