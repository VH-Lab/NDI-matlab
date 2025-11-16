"""
Validate cloud metadata structure.

This module provides validation for metadata structures before they are
uploaded to the NDI Cloud.

MATLAB Source: ndi/+ndi/+cloud/+utility/mustBeValidMetadata.m
"""

from typing import Dict, Any


def must_be_valid_metadata(metadata_struct: Dict[str, Any]) -> None:
    """
    Validate that metadata structure is valid for cloud upload.

    This function checks if a metadata structure contains all required fields
    and has the correct structure for NDI cloud upload. It validates:
      - Required top-level fields
      - Author structure and fields
      - Funding structure
      - Digital identifier structure

    Args:
        metadata_struct: A dictionary with the metadata to validate

    Raises:
        ValueError: If the metadata structure is missing required fields
            or has an invalid structure

    Example:
        >>> from ndi.cloud.utility import must_be_valid_metadata
        >>> metadata = {
        ...     'DatasetFullName': 'My Dataset',
        ...     'DatasetShortName': 'my-dataset',
        ...     'Description': ['A sample dataset'],
        ...     'Author': [{
        ...         'givenName': 'John',
        ...         'familyName': 'Doe',
        ...         'authorRole': 'Corresponding',
        ...         'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
        ...     }],
        ...     'Funding': [{'funder': 'NSF'}],
        ...     'License': 'CC BY 4.0',
        ...     'Subjects': []
        ... }
        >>> must_be_valid_metadata(metadata)  # Should pass without error
        >>>
        >>> # Missing required field
        >>> invalid_metadata = {'DatasetFullName': 'Test'}
        >>> must_be_valid_metadata(invalid_metadata)  # Raises ValueError

    Note:
        This is a validation function that raises an exception if the
        metadata is invalid. It does not return a value on success.

    See Also:
        create_cloud_metadata_struct

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+utility/mustBeValidMetadata.m
        ndi/+ndi/+database/+metadata_ds_core/check_metadata_cloud_inputs.m
    """
    is_valid = check_metadata_cloud_inputs(metadata_struct)

    if not is_valid:
        raise ValueError(
            'NDI:CLOUD:CREATE_CLOUD_METADATA_STRUCT - '
            'metadata_struct is missing required fields'
        )


def check_metadata_cloud_inputs(metadata_struct: Dict[str, Any]) -> bool:
    """
    Check if the metadata structure is valid for cloud upload.

    This function validates the structure and required fields of metadata
    intended for cloud upload.

    Args:
        metadata_struct: A dictionary with fields:
            - DatasetFullName: Full name of the dataset
            - DatasetShortName: Short name/identifier for the dataset
            - Author: List of author dictionaries with fields:
                - givenName: Author's first name
                - familyName: Author's last name
                - authorRole: Role (e.g., 'Corresponding', 'Creator')
                - digitalIdentifier: Dictionary with 'identifier' field (ORCID)
            - Funding: List of funding dictionaries with 'funder' field
            - Description: Description text (string or list)
            - License: License information
            - Subjects: List of subject information

    Returns:
        True if the metadata structure is valid, False otherwise

    MATLAB Source Reference:
        ndi/+ndi/+database/+metadata_ds_core/check_metadata_cloud_inputs.m
    """
    # Required top-level fields
    required_fields = [
        'DatasetFullName',
        'DatasetShortName',
        'Author',
        'Funding',
        'Description',
        'License',
        'Subjects'
    ]

    # Check if all required fields are present
    if not all(field in metadata_struct for field in required_fields):
        return False

    # Validate Author structure
    if 'Author' in metadata_struct:
        author_fields = ['givenName', 'familyName', 'authorRole', 'digitalIdentifier']

        # Author should be a list
        authors = metadata_struct['Author']
        if not isinstance(authors, list):
            authors = [authors]

        for author in authors:
            # Check author has all required fields
            if not all(field in author for field in author_fields):
                return False

            # Check digitalIdentifier structure
            if 'digitalIdentifier' in author:
                digital_id = author['digitalIdentifier']
                if not isinstance(digital_id, dict) or 'identifier' not in digital_id:
                    return False

    # Validate Funding structure
    if 'Funding' in metadata_struct:
        funding_entries = metadata_struct['Funding']
        if not isinstance(funding_entries, list):
            funding_entries = [funding_entries]

        for funding in funding_entries:
            if not isinstance(funding, dict) or 'funder' not in funding:
                return False

    # Note: In MATLAB, Subjects is checked to be an instance of a specific class
    # In Python, we'll just check if it exists (the structure can vary)
    # More specific validation can be added if needed

    return True
