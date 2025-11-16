"""Convert contributor information to Crossref format.

This module converts contributor/author information from NDI Cloud format
to the Crossref required format, including ORCID handling.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertContributors.m
"""

import re
from typing import Dict, Any, List, Optional


def convert_contributors(cloud_dataset: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
    """Convert contributor information to Crossref format.

    Transforms the contributors list from NDI Cloud format to Crossref person_name
    format, including:
    - First/given name and surname extraction
    - Sequence attribute assignment (first vs additional)
    - ORCID ID formatting and validation
    - Contributor role assignment (author)

    Args:
        cloud_dataset: Dictionary containing dataset metadata with a 'contributors'
            field. Each contributor should have:
            - firstName: (optional) Given name
            - lastName: (optional) Surname
            - orcid: (optional) ORCID identifier (with or without URL prefix)

    Returns:
        Dictionary with 'items' key containing a list of contributor dictionaries.
        Each contributor has:
        - given_name: Given/first name (may be None)
        - surname: Last/family name (may be None)
        - orcid: ORCID object with 'value' (may be None)
        - sequence: 'first' for first contributor, 'additional' for others
        - contributor_role: 'author'

    Note:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertContributors.m

    Example:
        >>> dataset = {
        ...     'contributors': [
        ...         {'firstName': 'John', 'lastName': 'Doe', 'orcid': '0000-0001-2345-6789'},
        ...         {'firstName': 'Jane', 'lastName': 'Smith'}
        ...     ]
        ... }
        >>> result = convert_contributors(dataset)
        >>> print(result['items'][0]['given_name'])
        'John'
        >>> print(result['items'][0]['orcid']['value'])
        'https://orcid.org/0000-0001-2345-6789'
    """
    contributors_list = cloud_dataset.get('contributors', [])

    # Create person_name objects for contributors
    person_names = []

    for i, contributor in enumerate(contributors_list):
        # Determine sequence attribute (first or additional)
        sequence = 'first' if i == 0 else 'additional'

        # Extract names
        given_name = contributor.get('firstName')
        surname = contributor.get('lastName')

        # Handle ORCID
        orcid_obj = None
        if 'orcid' in contributor and contributor['orcid']:
            orcid_value = contributor['orcid']
            # Append orcid prefix if only numbers are given
            if re.match(r'^\d{4}-\d{4}-\d{4}-\d{4}$', orcid_value):
                orcid_value = f"https://orcid.org/{orcid_value}"
            orcid_obj = {'value': orcid_value}

        # Create person_name object
        person_name = {
            'given_name': given_name,
            'surname': surname,
            'orcid': orcid_obj,
            'sequence': sequence,
            'contributor_role': 'author'  # crossref.enum.ContributorRole.author
        }

        person_names.append(person_name)

    # Create contributors object
    contributors_obj = {
        'items': person_names
    }

    return contributors_obj


# Object-oriented approach (alternative implementation)

class ORCID:
    """ORCID identifier for a contributor.

    Attributes:
        value: Full ORCID URL (e.g., https://orcid.org/0000-0001-2345-6789)
    """

    def __init__(self, value: str):
        """Initialize ORCID.

        Args:
            value: ORCID URL or numeric identifier
        """
        # Ensure value has the ORCID URL prefix
        if re.match(r'^\d{4}-\d{4}-\d{4}-\d{4}$', value):
            value = f"https://orcid.org/{value}"
        self.value = value

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with value
        """
        return {'value': self.value}

    @staticmethod
    def validate(orcid_str: str) -> bool:
        """Validate ORCID format.

        Args:
            orcid_str: ORCID string to validate

        Returns:
            True if valid format, False otherwise
        """
        # Check if it's a numeric ORCID
        if re.match(r'^\d{4}-\d{4}-\d{4}-\d{4}$', orcid_str):
            return True
        # Check if it's a full ORCID URL
        if re.match(r'^https://orcid\.org/\d{4}-\d{4}-\d{4}-\d{4}$', orcid_str):
            return True
        return False


class PersonName:
    """Person name information for a contributor.

    Attributes:
        given_name: Given/first name
        surname: Surname/last name
        orcid: ORCID object (optional)
        sequence: Sequence indicator ('first' or 'additional')
        contributor_role: Role of contributor (e.g., 'author')
    """

    def __init__(
        self,
        given_name: Optional[str],
        surname: Optional[str],
        orcid: Optional[ORCID],
        sequence: str,
        contributor_role: str
    ):
        """Initialize PersonName.

        Args:
            given_name: Given/first name
            surname: Surname/last name
            orcid: ORCID object
            sequence: 'first' or 'additional'
            contributor_role: Role string (e.g., 'author')
        """
        self.given_name = given_name
        self.surname = surname
        self.orcid = orcid
        self.sequence = sequence
        self.contributor_role = contributor_role

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary.

        Returns:
            Dictionary representation
        """
        result = {
            'given_name': self.given_name,
            'surname': self.surname,
            'sequence': self.sequence,
            'contributor_role': self.contributor_role
        }
        if self.orcid:
            result['orcid'] = self.orcid.to_dict()
        else:
            result['orcid'] = None
        return result


class Contributors:
    """Contributors collection.

    Attributes:
        items: List of PersonName objects
    """

    def __init__(self, items: List[PersonName]):
        """Initialize Contributors.

        Args:
            items: List of PersonName objects
        """
        self.items = items

    def to_dict(self) -> Dict[str, List[Dict[str, Any]]]:
        """Convert to dictionary.

        Returns:
            Dictionary with items list
        """
        return {
            'items': [item.to_dict() for item in self.items]
        }


def convert_contributors_object(cloud_dataset: Dict[str, Any]) -> Contributors:
    """Convert contributors to Contributors object.

    Alternative to convert_contributors() that returns a Contributors object
    instead of a dictionary.

    Args:
        cloud_dataset: Cloud dataset dictionary with contributors

    Returns:
        Contributors object

    Example:
        >>> dataset = {'contributors': [{'firstName': 'John', 'lastName': 'Doe'}]}
        >>> contributors = convert_contributors_object(dataset)
        >>> print(contributors.items[0].given_name)
        'John'
    """
    contributors_list = cloud_dataset.get('contributors', [])
    person_names = []

    for i, contributor in enumerate(contributors_list):
        sequence = 'first' if i == 0 else 'additional'
        given_name = contributor.get('firstName')
        surname = contributor.get('lastName')

        # Handle ORCID
        orcid_obj = None
        if 'orcid' in contributor and contributor['orcid']:
            orcid_obj = ORCID(contributor['orcid'])

        person_name = PersonName(
            given_name=given_name,
            surname=surname,
            orcid=orcid_obj,
            sequence=sequence,
            contributor_role='author'
        )

        person_names.append(person_name)

    return Contributors(items=person_names)
