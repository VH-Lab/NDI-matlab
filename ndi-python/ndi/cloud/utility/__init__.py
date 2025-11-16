"""
NDI Cloud Utility Module

Utility functions for cloud metadata creation and validation.
These functions support dataset metadata preparation and validation for cloud upload.

MATLAB Source: ndi/+ndi/+cloud/+utility/
"""

from .create_cloud_metadata_struct import create_cloud_metadata_struct
from .must_be_valid_metadata import must_be_valid_metadata

__all__ = [
    'create_cloud_metadata_struct',
    'must_be_valid_metadata',
]
