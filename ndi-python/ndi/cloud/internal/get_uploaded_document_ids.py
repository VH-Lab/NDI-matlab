"""
Get a list of NDI IDs for all documents uploaded to a cloud dataset.

This module retrieves all documents from a cloud dataset and returns
their NDI IDs.

MATLAB Source: ndi/+ndi/+cloud/+internal/getUploadedDocumentIds.m
"""

from typing import List


def get_uploaded_document_ids(dataset_id: str) -> List[str]:
    """
    Get a list of uploaded document NDI IDs.

    This function retrieves a complete list of all documents associated with a
    specific cloud dataset and returns their NDI IDs.

    It calls the ndi.cloud.api.documents.list_dataset_documents_all function to
    fetch all document metadata from the remote server. If the API call is
    successful, it extracts the 'ndiId' field from each document record.

    If the dataset contains no documents, the function returns an empty list.

    Args:
        dataset_id: The unique identifier of the cloud dataset

    Returns:
        A list containing the NDI IDs of all documents in the dataset.
        Returns an empty list if the dataset has no documents.

    Raises:
        RuntimeError: If the API call fails to list dataset documents

    Example:
        >>> from ndi.cloud.internal import get_uploaded_document_ids
        >>> # Assume 'd-12345' is a valid cloud dataset ID
        >>> doc_ids = get_uploaded_document_ids('d-12345')
        >>> if not doc_ids:
        ...     print('No documents found in the dataset.')
        ... else:
        ...     print(f'Found {len(doc_ids)} documents.')

    See Also:
        ndi.cloud.api.documents.list_dataset_documents_all

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/getUploadedDocumentIds.m
    """
    from ndi.cloud.api.documents import list_dataset_documents_all

    # Get all documents from the cloud dataset
    success, result = list_dataset_documents_all(dataset_id)

    if not success:
        error_msg = result.get('message', 'Unknown error') if isinstance(result, dict) else str(result)
        raise RuntimeError(f'Failed to list dataset documents: {error_msg}')

    # Extract NDI IDs from documents
    if result:
        uploaded_document_ids = [doc['ndiId'] for doc in result if 'ndiId' in doc]
    else:
        uploaded_document_ids = []

    return uploaded_document_ids
