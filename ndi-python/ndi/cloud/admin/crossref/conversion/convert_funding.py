"""Convert funding information to Crossref format.

This module converts funding information from NDI Cloud format to the
Crossref Funding Program format.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertFunding.m
"""

from typing import Dict, Any, List, Optional


def convert_funding(cloud_dataset: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Convert funding information to Crossref Funding Program format.

    Extracts funding information from the dataset and converts it to the
    Crossref FR (FundRef) Program structure with funding assertions.

    Args:
        cloud_dataset: Dictionary containing dataset metadata with optional
            'funding' field. The funding field should be a list of dictionaries,
            each containing:
            - source: Funding source/organization name

    Returns:
        Dictionary representing FR Program with assertions, or None if no
        funding is specified. The structure includes:
        - assertion: List of assertion dictionaries, each with:
            - name: 'funder_name'
            - value: Funder name string

        Returns None if funding field is missing or empty.

    Note:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertFunding.m

    Example:
        >>> dataset = {
        ...     'funding': [
        ...         {'source': 'NIH'},
        ...         {'source': 'NSF'}
        ...     ]
        ... }
        >>> result = convert_funding(dataset)
        >>> print(len(result['assertion']))
        2
        >>> print(result['assertion'][0]['value'])
        'NIH'
        >>>
        >>> # With no funding
        >>> dataset = {}
        >>> result = convert_funding(dataset)
        >>> print(result)
        None
    """
    # Check if funding field exists and is not empty
    if 'funding' not in cloud_dataset or not cloud_dataset['funding']:
        return None

    funding_details = cloud_dataset['funding']

    # Create FR assertions for each funding source
    fr_assertions = []
    for funding_item in funding_details:
        assertion = {
            'name': 'funder_name',
            'value': str(funding_item.get('source', ''))
        }
        fr_assertions.append(assertion)

    # Create FR Program object
    funding_obj = {
        'assertion': fr_assertions
    }

    return funding_obj


# Object-oriented approach (alternative implementation)

class FrAssertion:
    """Funding Reference (FundRef) Assertion for Crossref.

    Attributes:
        name: Assertion name (typically 'funder_name')
        value: Funder name or other assertion value
    """

    def __init__(self, name: str, value: str):
        """Initialize FrAssertion.

        Args:
            name: Assertion name
            value: Assertion value
        """
        self.name = name
        self.value = value

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with name and value
        """
        return {
            'name': self.name,
            'value': self.value
        }


class FrProgram:
    """Funding Reference Program for Crossref.

    Attributes:
        assertion: List of FrAssertion objects
    """

    def __init__(self, assertion: List[FrAssertion]):
        """Initialize FrProgram.

        Args:
            assertion: List of FrAssertion objects
        """
        self.assertion = assertion

    def to_dict(self) -> Dict[str, List[Dict[str, str]]]:
        """Convert to dictionary.

        Returns:
            Dictionary with assertion list
        """
        return {
            'assertion': [a.to_dict() for a in self.assertion]
        }


def convert_funding_object(cloud_dataset: Dict[str, Any]) -> Optional[FrProgram]:
    """Convert funding to FrProgram object.

    Alternative to convert_funding() that returns an FrProgram object
    instead of a dictionary.

    Args:
        cloud_dataset: Cloud dataset dictionary with funding

    Returns:
        FrProgram object or None if no funding

    Example:
        >>> dataset = {'funding': [{'source': 'NIH'}]}
        >>> fr_program = convert_funding_object(dataset)
        >>> print(fr_program.assertion[0].value)
        'NIH'
    """
    funding_dict = convert_funding(cloud_dataset)

    if funding_dict is None:
        return None

    # Create FrAssertion objects
    assertions = []
    for assertion_dict in funding_dict['assertion']:
        assertion = FrAssertion(
            name=assertion_dict['name'],
            value=assertion_dict['value']
        )
        assertions.append(assertion)

    fr_program = FrProgram(assertion=assertions)

    return fr_program


def parse_funding_from_text(funding_text: str) -> List[Dict[str, str]]:
    """Parse funding information from free text.

    This is a helper function to extract funding sources from unstructured
    text, which may be useful for datasets that don't have structured funding
    information.

    Args:
        funding_text: Free text containing funding information

    Returns:
        List of funding dictionaries with 'source' keys

    Note:
        This is a simple implementation. More sophisticated parsing could
        use NLP or pattern matching to extract grant numbers, etc.

    Example:
        >>> text = "Funded by NIH and NSF"
        >>> funding = parse_funding_from_text(text)
        >>> print(funding)
        [{'source': 'Funded by NIH and NSF'}]
    """
    # Simple implementation: treat the entire text as one funding source
    # More sophisticated parsing could be added here
    if not funding_text or not funding_text.strip():
        return []

    return [{'source': funding_text.strip()}]
