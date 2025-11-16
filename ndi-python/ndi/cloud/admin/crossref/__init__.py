"""Crossref integration for NDI Cloud DOI registration.

This module provides functions for creating Crossref-compatible metadata structures
and XML documents for DOI registration.

Main Components:
    - Constants: Configuration values for Crossref submissions
    - create_doi_batch_head_element: Create DOI batch head metadata
    - create_doi_batch_submission: Create complete DOI batch submission
    - create_database_metadata: Create database metadata for NDI Cloud
    - convert_cloud_dataset_to_crossref_dataset: Convert NDI dataset to Crossref format

Submodules:
    - conversion: Metadata conversion utilities for specific fields

Ported from: ndi/+ndi/+cloud/+admin/+crossref/
"""

from ndi.cloud.admin.crossref.constants import Constants
from ndi.cloud.admin.crossref.create_doi_batch_head_element import (
    create_doi_batch_head_element,
    create_doi_batch_head_element_object,
    Head,
    Depositor,
)
from ndi.cloud.admin.crossref.create_doi_batch_submission import (
    create_doi_batch_submission,
    create_doi_batch_submission_object,
    DoiBatch,
    Body,
    Database,
)
from ndi.cloud.admin.crossref.create_database_metadata import (
    create_database_metadata,
    create_database_metadata_object,
    DatabaseMetadata,
    Titles,
    Organization,
    DatabaseDate,
    CreationDate,
    PublicationDate,
    DoiData,
    Contributors,
)
from ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref import (
    convert_cloud_dataset_to_crossref_dataset,
    convert_cloud_dataset_to_crossref_dataset_object,
    Dataset,
)

__all__ = [
    # Constants
    'Constants',
    # Functions
    'create_doi_batch_head_element',
    'create_doi_batch_head_element_object',
    'create_doi_batch_submission',
    'create_doi_batch_submission_object',
    'create_database_metadata',
    'create_database_metadata_object',
    'convert_cloud_dataset_to_crossref_dataset',
    'convert_cloud_dataset_to_crossref_dataset_object',
    # Classes
    'Head',
    'Depositor',
    'DoiBatch',
    'Body',
    'Database',
    'DatabaseMetadata',
    'Titles',
    'Organization',
    'DatabaseDate',
    'CreationDate',
    'PublicationDate',
    'DoiData',
    'Contributors',
    'Dataset',
]
