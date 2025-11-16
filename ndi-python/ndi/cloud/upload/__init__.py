"""
NDI Cloud Upload - Functions for uploading data to NDI Cloud.

This module provides functionality for uploading NDI datasets, documents,
and files to the NDI Cloud storage system.

Main Functions:
    - upload_document_collection: Upload multiple documents in batches
    - new_dataset: Create and upload a new dataset to NDI Cloud
    - scan_for_upload: Scan a session for documents/files ready to upload
    - zip_for_upload: Batch and upload binary files in zip archives
    - upload_to_ndicloud: Main orchestration function for complete uploads

MATLAB Source: ndi/+ndi/+cloud/+upload/
"""

from .upload_collection import upload_document_collection
from .new_dataset import new_dataset
from .scan_for_upload import scan_for_upload
from .zip_for_upload import zip_for_upload
from .upload_to_ndicloud import upload_to_ndicloud

__all__ = [
    'upload_document_collection',
    'new_dataset',
    'scan_for_upload',
    'zip_for_upload',
    'upload_to_ndicloud',
]
