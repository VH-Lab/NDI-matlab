"""
NDI Cloud Download - Download datasets and documents from NDI Cloud.

This module provides functionality for downloading datasets, documents,
and associated files from the NDI Cloud service.

Ported from MATLAB: ndi.cloud.download
"""

from .dataset import download_dataset
from .download_collection import download_document_collection
from .jsons2documents import jsons_to_documents
from .dataset_documents import download_dataset_documents
from .download_dataset_files import download_dataset_files

__all__ = [
    'download_dataset',
    'download_document_collection',
    'jsons_to_documents',
    'download_dataset_documents',
    'download_dataset_files',
]
