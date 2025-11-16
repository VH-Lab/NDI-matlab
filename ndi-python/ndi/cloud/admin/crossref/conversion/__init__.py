"""Crossref metadata conversion utilities.

This module provides conversion functions to transform NDI Cloud dataset metadata
into Crossref-compatible formats for specific metadata fields.

Conversion Functions:
    - convert_contributors: Convert author/contributor information with ORCID
    - convert_license: Convert license information to AI Program format
    - convert_funding: Convert funding information to FR Program format
    - convert_dataset_date: Convert date information (creation, publication, update)
    - convert_related_publications: Convert related publications to REL Program format

Ported from: ndi/+ndi/+cloud/+admin/+crossref/+conversion/
"""

from ndi.cloud.admin.crossref.conversion.convert_contributors import (
    convert_contributors,
    convert_contributors_object,
    ORCID,
    PersonName,
    Contributors,
)
from ndi.cloud.admin.crossref.conversion.convert_license import (
    convert_license,
    convert_license_object,
    add_license_mapping,
    AiLicenseRef,
    AiProgram,
    LICENSE_URL_MAP,
)
from ndi.cloud.admin.crossref.conversion.convert_funding import (
    convert_funding,
    convert_funding_object,
    parse_funding_from_text,
    FrAssertion,
    FrProgram,
)
from ndi.cloud.admin.crossref.conversion.convert_dataset_date import (
    convert_dataset_date,
    convert_dataset_date_object,
    timestamp_to_year_month_day,
    PublicationDate,
    CreationDate,
    UpdateDate,
    DatabaseDate,
)
from ndi.cloud.admin.crossref.conversion.convert_related_publications import (
    convert_related_publications,
    convert_related_publications_object,
    create_related_item,
    RelRelatedItem,
    RelProgram,
    RELATIONSHIP_TYPES,
)

__all__ = [
    # Contributor conversion
    'convert_contributors',
    'convert_contributors_object',
    'ORCID',
    'PersonName',
    'Contributors',
    # License conversion
    'convert_license',
    'convert_license_object',
    'add_license_mapping',
    'AiLicenseRef',
    'AiProgram',
    'LICENSE_URL_MAP',
    # Funding conversion
    'convert_funding',
    'convert_funding_object',
    'parse_funding_from_text',
    'FrAssertion',
    'FrProgram',
    # Date conversion
    'convert_dataset_date',
    'convert_dataset_date_object',
    'timestamp_to_year_month_day',
    'PublicationDate',
    'CreationDate',
    'UpdateDate',
    'DatabaseDate',
    # Related publications conversion
    'convert_related_publications',
    'convert_related_publications_object',
    'create_related_item',
    'RelRelatedItem',
    'RelProgram',
    'RELATIONSHIP_TYPES',
]
