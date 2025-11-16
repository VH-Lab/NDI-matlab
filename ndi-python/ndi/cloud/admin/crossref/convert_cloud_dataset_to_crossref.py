"""Convert NDI Cloud dataset to Crossref format.

This module converts dataset metadata from NDI Cloud format to the format
required by Crossref for DOI registration.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/convertCloudDatasetToCrossrefDataset.m
"""

from typing import Dict, Any, Optional

from ndi.cloud.admin.create_new_doi import create_new_doi
from ndi.cloud.admin.crossref.constants import Constants


def convert_cloud_dataset_to_crossref_dataset(
    cloud_dataset: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """Convert NDI Cloud dataset metadata to Crossref dataset format.

    This function transforms dataset metadata from the NDI Cloud internal format
    to the structure required by Crossref for DOI registration. It includes:
    - Title conversion
    - Contributor/author information (with ORCID)
    - Dataset dates (creation, publication, update)
    - License information
    - Funding information
    - DOI generation and resource URL

    Args:
        cloud_dataset: Dictionary containing dataset metadata from NDI Cloud.
            Expected fields:
            - name: Dataset title
            - abstract: Dataset description
            - contributors: List of contributor dictionaries
            - createdAt: ISO timestamp
            - updatedAt: ISO timestamp
            - license: License identifier
            - funding: List of funding sources
            - x_id: Dataset identifier

    Returns:
        Dictionary in Crossref format, or None if cloud_dataset is empty.
        Returns a dictionary with:
        - contributors: Contributor information
        - titles: Title information
        - description: Dataset description
        - doi_data: DOI and resource URL
        - dataset_type: Type of dataset ('record')
        - database_date: Date information
        - ai_program: License information
        - fr_program: Funding information

    Notes:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/convertCloudDatasetToCrossrefDataset.m

        TODO items from MATLAB (Crossref best practice recommendations):
        - [x] Include funding
        - [x] Include license
        - [ ] Include relationship metadata
        - [x] Include all contributors with names and ORCID
        - [x] Include relevant dates (creation, publication, update)
        - [x] Provide description
        - [ ] Provide format
        - [ ] Provide citation metadata

    Example:
        >>> cloud_dataset = {
        ...     'name': 'My Dataset',
        ...     'abstract': 'A description',
        ...     'contributors': [{'firstName': 'John', 'lastName': 'Doe'}],
        ...     'createdAt': '2025-01-15T10:00:00.000Z',
        ...     'updatedAt': '2025-01-15T11:00:00.000Z',
        ...     'x_id': 'abc123'
        ... }
        >>> crossref_dataset = convert_cloud_dataset_to_crossref_dataset(cloud_dataset)
        >>> print(crossref_dataset['titles']['title'])
        'My Dataset'
    """
    # Import conversion functions here to avoid circular imports
    from ndi.cloud.admin.crossref.conversion.convert_contributors import (
        convert_contributors
    )
    from ndi.cloud.admin.crossref.conversion.convert_dataset_date import (
        convert_dataset_date
    )
    from ndi.cloud.admin.crossref.conversion.convert_license import convert_license
    from ndi.cloud.admin.crossref.conversion.convert_funding import convert_funding

    # Handle empty dataset
    if not cloud_dataset:
        return None

    # Create titles object
    title = {
        'title': cloud_dataset.get('name', '')
    }

    # Convert various metadata components
    contributors = convert_contributors(cloud_dataset)
    dataset_date = convert_dataset_date(cloud_dataset)
    ai_program = convert_license(cloud_dataset)
    funding_program = convert_funding(cloud_dataset)

    # Note: Related publications conversion is commented out in MATLAB version
    # related_publications = convert_related_publications(cloud_dataset)

    # Ensure no DOI is present on the dataset already
    # TODO: If a DOI is present, the metadata record for that DOI should be updated
    if 'doi' in cloud_dataset and cloud_dataset['doi']:
        raise ValueError(
            'Expected dataset to have no DOI from before. '
            'Dataset already has DOI: ' + cloud_dataset['doi']
        )

    # Create doi_data object
    doi_str = create_new_doi()
    dataset_url = Constants.get_dataset_url(cloud_dataset.get('x_id', ''))
    doi_data = {
        'doi': doi_str,
        'resource': dataset_url
    }

    # Create dataset object
    crossref_dataset = {
        'contributors': contributors,
        'titles': title,
        'description': cloud_dataset.get('abstract', ''),
        'doi_data': doi_data,
        'dataset_type': 'record',  # crossref.enum.DatasetType.record
        'database_date': dataset_date,
        'ai_program': ai_program,
        'fr_program': funding_program
    }

    return crossref_dataset


# Object-oriented approach (alternative implementation)

class Dataset:
    """Crossref dataset metadata structure.

    Attributes:
        contributors: Contributors information
        titles: Title information
        description: Dataset description
        doi_data: DOI and resource URL
        dataset_type: Type of dataset
        database_date: Date information
        ai_program: License/AI program information
        fr_program: Funding program information
    """

    def __init__(
        self,
        contributors: Dict[str, Any],
        titles: Dict[str, str],
        description: str,
        doi_data: Dict[str, str],
        dataset_type: str,
        database_date: Dict[str, Any],
        ai_program: Optional[Dict[str, Any]] = None,
        fr_program: Optional[Dict[str, Any]] = None
    ):
        """Initialize Dataset.

        Args:
            contributors: Contributors dictionary
            titles: Titles dictionary
            description: Description text
            doi_data: DOI data dictionary
            dataset_type: Dataset type string
            database_date: Database date dictionary
            ai_program: AI/License program dictionary (optional)
            fr_program: Funding program dictionary (optional)
        """
        self.contributors = contributors
        self.titles = titles
        self.description = description
        self.doi_data = doi_data
        self.dataset_type = dataset_type
        self.database_date = database_date
        self.ai_program = ai_program
        self.fr_program = fr_program

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation.

        Returns:
            Dictionary with all dataset fields
        """
        result = {
            'contributors': self.contributors,
            'titles': self.titles,
            'description': self.description,
            'doi_data': self.doi_data,
            'dataset_type': self.dataset_type,
            'database_date': self.database_date
        }

        if self.ai_program:
            result['ai_program'] = self.ai_program
        if self.fr_program:
            result['fr_program'] = self.fr_program

        return result


def convert_cloud_dataset_to_crossref_dataset_object(
    cloud_dataset: Dict[str, Any]
) -> Optional[Dataset]:
    """Convert cloud dataset to Crossref Dataset object.

    Alternative to convert_cloud_dataset_to_crossref_dataset() that returns
    a Dataset object instead of a dictionary.

    Args:
        cloud_dataset: Cloud dataset metadata dictionary

    Returns:
        Dataset object or None if input is empty

    Example:
        >>> cloud_dataset = {'name': 'My Dataset', 'x_id': 'abc123'}
        >>> dataset = convert_cloud_dataset_to_crossref_dataset_object(cloud_dataset)
        >>> print(dataset.titles['title'])
        'My Dataset'
    """
    dataset_dict = convert_cloud_dataset_to_crossref_dataset(cloud_dataset)

    if dataset_dict is None:
        return None

    dataset = Dataset(
        contributors=dataset_dict['contributors'],
        titles=dataset_dict['titles'],
        description=dataset_dict['description'],
        doi_data=dataset_dict['doi_data'],
        dataset_type=dataset_dict['dataset_type'],
        database_date=dataset_dict['database_date'],
        ai_program=dataset_dict.get('ai_program'),
        fr_program=dataset_dict.get('fr_program')
    )

    return dataset
