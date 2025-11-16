"""Create new DOI strings for NDI Cloud datasets.

This module generates unique Digital Object Identifiers (DOIs) for datasets
using random and opaque suffixes.

Ported from: ndi/+ndi/+cloud/+admin/createNewDOI.m
"""

import random
import string
from datetime import datetime
from typing import Optional


def create_new_doi() -> str:
    """Create a DOI string using a random and opaque DOI suffix.

    Generates a unique DOI in the format: <prefix>/<year>.<random_suffix>
    where the random suffix is an 8-character alphanumeric string.

    The DOI format follows the pattern:
        10.63884/ndic.YYYY.xxxxxxxx

    where:
        - 10.63884 is the NDI Cloud DOI prefix
        - YYYY is the current year
        - xxxxxxxx is a random 8-character string (lowercase letters and digits)

    Returns:
        A unique DOI string

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/createNewDOI.m

    Example:
        >>> doi = create_new_doi()
        >>> print(doi)
        '10.63884/ndic.2025.a3f7k9m2'
    """
    from ndi.cloud.admin.crossref.constants import Constants

    random_suffix = generate_random_doi_suffix()
    current_year = datetime.now().year
    doi_suffix = f'ndic.{current_year}.{random_suffix}'

    ndi_prefix = Constants.DOI_PREFIX
    doi = f'{ndi_prefix}/{doi_suffix}'

    return doi


def generate_random_doi_suffix(length: int = 8) -> str:
    """Generate a random DOI suffix of specified length.

    Creates a random string consisting of lowercase letters and digits.
    This suffix is used to ensure uniqueness of DOIs.

    Args:
        length: The length of the random suffix (default: 8)

    Returns:
        A random string of lowercase letters and digits

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/createNewDOI.m
        (internal function generateRandomDOISuffix)

    Example:
        >>> suffix = generate_random_doi_suffix(8)
        >>> len(suffix)
        8
        >>> all(c in string.ascii_lowercase + string.digits for c in suffix)
        True
    """
    # Characters to choose from: a-z and 0-9
    chars = string.ascii_lowercase + string.digits

    # Generate random suffix
    suffix = ''.join(random.choice(chars) for _ in range(length))

    return suffix
