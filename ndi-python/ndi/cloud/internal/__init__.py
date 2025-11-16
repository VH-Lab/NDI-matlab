"""
NDI Cloud Internal Module

Internal utilities and helper functions for NDI cloud operations.
These functions support authentication, dataset linking, and cloud API operations.

MATLAB Source: ndi/+ndi/+cloud/+internal/
"""

from .get_cloud_dataset_id_for_local_dataset import get_cloud_dataset_id_for_local_dataset
from .decode_jwt import decode_jwt
from .get_uploaded_file_ids import get_uploaded_file_ids
from .create_remote_dataset_doc import create_remote_dataset_doc
from .duplicate_documents import duplicate_documents
from .get_active_token import get_active_token
from .get_token_expiration import get_token_expiration
from .get_uploaded_document_ids import get_uploaded_document_ids
from .get_weboptions_with_auth_header import get_weboptions_with_auth_header

__all__ = [
    'get_cloud_dataset_id_for_local_dataset',
    'decode_jwt',
    'get_uploaded_file_ids',
    'create_remote_dataset_doc',
    'duplicate_documents',
    'get_active_token',
    'get_token_expiration',
    'get_uploaded_document_ids',
    'get_weboptions_with_auth_header',
]
