"""NDI Cloud Admin module for DOI registration and dataset management.

This module provides functionality for registering Digital Object Identifiers (DOIs)
for NDI Cloud datasets through the Crossref DOI registration service.

Main Functions:
    - register_dataset_doi: Register a DOI for a published dataset
    - create_new_doi: Create a new DOI string with random suffix
    - check_submission: Check status of a DOI submission to Crossref

Submodules:
    - crossref: Crossref integration and XML generation
    - crossref.conversion: Metadata conversion utilities

Ported from: ndi/+ndi/+cloud/+admin/
"""

from ndi.cloud.admin.register_dataset_doi import register_dataset_doi
from ndi.cloud.admin.create_new_doi import create_new_doi, generate_random_doi_suffix
from ndi.cloud.admin.check_submission import check_submission

__all__ = [
    'register_dataset_doi',
    'create_new_doi',
    'generate_random_doi_suffix',
    'check_submission',
]
