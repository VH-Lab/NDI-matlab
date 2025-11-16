"""Convert license information to Crossref format.

This module converts license information from NDI Cloud format to the
Crossref AI Program format for license references.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertLicense.m
"""

from typing import Dict, Any, Optional


# License name to URL mapping
# Based on common Creative Commons and other open licenses
LICENSE_URL_MAP = {
    'CC-BY-4.0': 'https://creativecommons.org/licenses/by/4.0/',
    'CC-BY-NC-4.0': 'https://creativecommons.org/licenses/by-nc/4.0/',
    'CC-BY-NC-SA-4.0': 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
    'CC-BY-NC-ND-4.0': 'https://creativecommons.org/licenses/by-nc-nd/4.0/',
    'CC-BY-SA-4.0': 'https://creativecommons.org/licenses/by-sa/4.0/',
    'CC-BY-ND-4.0': 'https://creativecommons.org/licenses/by-nd/4.0/',
    'CC0-1.0': 'https://creativecommons.org/publicdomain/zero/1.0/',
    'MIT': 'https://opensource.org/licenses/MIT',
    'Apache-2.0': 'https://www.apache.org/licenses/LICENSE-2.0',
    'GPL-3.0': 'https://www.gnu.org/licenses/gpl-3.0.html',
    # Handle variations
    'ccByNcSa4_0': 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
    'Creative Commons Attribution 4.0 International': 'https://creativecommons.org/licenses/by/4.0/',
}


def convert_license(cloud_dataset: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Convert license information to Crossref AI Program format.

    Extracts license information from the dataset and converts it to the
    Crossref AI Program structure with license references. The license name
    is mapped to its corresponding URL.

    Args:
        cloud_dataset: Dictionary containing dataset metadata with optional
            'license' field containing the license name or identifier.

    Returns:
        Dictionary representing AI Program with license reference, or None
        if no license is specified. The structure includes:
        - license_ref: Dictionary with 'value' (license URL)

        Returns None if license field is missing or empty.

    Note:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertLicense.m

        The MATLAB version uses openminds.core.License.fromName() to get
        license details. In Python, we use a mapping dictionary.

    Example:
        >>> dataset = {'license': 'CC-BY-4.0'}
        >>> result = convert_license(dataset)
        >>> print(result['license_ref']['value'])
        'https://creativecommons.org/licenses/by/4.0/'
        >>>
        >>> # With no license
        >>> dataset = {}
        >>> result = convert_license(dataset)
        >>> print(result)
        None
    """
    # Check if license field exists and is not empty
    if 'license' not in cloud_dataset or not cloud_dataset['license']:
        return None

    license_name = cloud_dataset['license']

    # Get license URL from mapping
    license_url = _get_license_url(license_name)

    if license_url is None:
        # If we can't find a mapping, try to use the license name as-is
        # in case it's already a URL
        if license_name.startswith('http://') or license_name.startswith('https://'):
            license_url = license_name
        else:
            # Last resort: construct a placeholder URL
            print(f"Warning: Unknown license '{license_name}', using placeholder URL")
            license_url = f"https://unknown-license.org/{license_name}"

    # Create AI Program object with license reference
    license_obj = {
        'license_ref': {
            'value': license_url
        }
    }

    return license_obj


def _get_license_url(license_name: str) -> Optional[str]:
    """Get license URL from license name.

    Args:
        license_name: License name or identifier

    Returns:
        License URL, or None if not found
    """
    # Try exact match first
    if license_name in LICENSE_URL_MAP:
        return LICENSE_URL_MAP[license_name]

    # Try case-insensitive match
    license_name_upper = license_name.upper()
    for key, url in LICENSE_URL_MAP.items():
        if key.upper() == license_name_upper:
            return url

    # Try to handle common variations
    # Replace underscores with hyphens
    normalized = license_name.replace('_', '-')
    if normalized in LICENSE_URL_MAP:
        return LICENSE_URL_MAP[normalized]

    return None


# Object-oriented approach (alternative implementation)

class AiLicenseRef:
    """AI License Reference for Crossref.

    Attributes:
        value: License URL
    """

    def __init__(self, value: str):
        """Initialize AiLicenseRef.

        Args:
            value: License URL
        """
        self.value = value

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary.

        Returns:
            Dictionary with value
        """
        return {'value': self.value}


class AiProgram:
    """AI Program for Crossref (used for license information).

    Attributes:
        license_ref: AiLicenseRef object
    """

    def __init__(self, license_ref: AiLicenseRef):
        """Initialize AiProgram.

        Args:
            license_ref: AiLicenseRef object
        """
        self.license_ref = license_ref

    def to_dict(self) -> Dict[str, Dict[str, str]]:
        """Convert to dictionary.

        Returns:
            Dictionary with license_ref
        """
        return {
            'license_ref': self.license_ref.to_dict()
        }


def convert_license_object(cloud_dataset: Dict[str, Any]) -> Optional[AiProgram]:
    """Convert license to AiProgram object.

    Alternative to convert_license() that returns an AiProgram object
    instead of a dictionary.

    Args:
        cloud_dataset: Cloud dataset dictionary with license

    Returns:
        AiProgram object or None if no license

    Example:
        >>> dataset = {'license': 'CC-BY-4.0'}
        >>> ai_program = convert_license_object(dataset)
        >>> print(ai_program.license_ref.value)
        'https://creativecommons.org/licenses/by/4.0/'
    """
    license_dict = convert_license(cloud_dataset)

    if license_dict is None:
        return None

    license_ref = AiLicenseRef(value=license_dict['license_ref']['value'])
    ai_program = AiProgram(license_ref=license_ref)

    return ai_program


def add_license_mapping(license_name: str, license_url: str) -> None:
    """Add a new license name to URL mapping.

    This allows extending the license mappings at runtime.

    Args:
        license_name: License name or identifier
        license_url: Corresponding license URL

    Example:
        >>> add_license_mapping('Custom-License-1.0', 'https://example.com/license')
    """
    LICENSE_URL_MAP[license_name] = license_url
