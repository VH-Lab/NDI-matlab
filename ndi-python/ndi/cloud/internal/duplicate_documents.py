"""
Find and optionally remove duplicate documents in a cloud dataset.

This module identifies documents with the same NDI ID but different cloud IDs,
and optionally deletes the duplicates.

MATLAB Source: ndi/+ndi/+cloud/+internal/duplicateDocuments.m
"""

from typing import Tuple, List, Dict, Any
import math


def duplicate_documents(
    cloud_dataset_id: str,
    delete_duplicates: bool = True,
    maximum_delete_batch_size: int = 1000,
    verbose: bool = False
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """
    Find and optionally remove duplicate documents in a cloud dataset.

    This function identifies duplicate documents within a specified NDI cloud dataset.
    Duplicates are defined as documents that share the same 'ndi.document.id' (or 'name'
    as a fallback) but may have different cloud-specific '_id' values.

    The function determines which document to keep as the 'original' and which to
    mark as a 'duplicate' based on the alphabetical order of their unique cloud document
    ID ('id'). The one with the alphabetically earliest 'id' is kept.

    By default, this function will delete the identified duplicate documents from the
    cloud dataset. This behavior can be controlled using a parameter.

    Args:
        cloud_dataset_id: The unique identifier of the cloud dataset
        delete_duplicates: If True, deletes the identified duplicates. Default: True
        maximum_delete_batch_size: The maximum number of documents to delete in
            a single bulk operation. Default: 1000
        verbose: If True, displays status messages. Default: False

    Returns:
        Tuple containing:
            - duplicate_docs: List of dictionaries representing documents that were
              identified as duplicates. These are the documents that were deleted
              if delete_duplicates is True.
            - original_docs: List of dictionaries representing documents that were
              identified as the originals.

    Raises:
        RuntimeError: If the API call to list documents fails

    Example:
        >>> from ndi.cloud.internal import duplicate_documents
        >>> # Find and delete duplicates
        >>> dups, originals = duplicate_documents('d-12345', verbose=True)
        >>> print(f'Found {len(dups)} duplicates and {len(originals)} originals')
        >>>
        >>> # Find but don't delete duplicates
        >>> dups, originals = duplicate_documents('d-12345', delete_duplicates=False)

    See Also:
        ndi.cloud.api.documents.list_dataset_documents_all
        ndi.cloud.api.documents.bulk_delete_documents

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/duplicateDocuments.m
    """
    from ndi.cloud.api.documents import list_dataset_documents_all, bulk_delete_documents

    duplicate_docs = []
    original_docs = []

    if verbose:
        print('Searching for all documents...')

    success, all_docs_list = list_dataset_documents_all(cloud_dataset_id)
    if not success:
        raise RuntimeError(f'Failed to list dataset documents: {all_docs_list}')

    if verbose:
        print('Done.')

    if not all_docs_list:
        return duplicate_docs, original_docs

    # Create a dictionary to track originals by their NDI ID or name
    doc_map = {}

    # Identify originals and duplicates
    for current_doc in all_docs_list:
        # Use ndiId if available, otherwise use name as the grouping key
        if 'ndiId' in current_doc and current_doc['ndiId']:
            doc_group_key = current_doc['ndiId']
        else:
            doc_group_key = current_doc.get('name', '')

        if not doc_group_key:
            # Skip documents without identifiers
            continue

        if doc_group_key not in doc_map:
            # First occurrence - mark as original
            doc_map[doc_group_key] = current_doc
        else:
            # Found a duplicate
            existing_doc = doc_map[doc_group_key]

            # Compare cloud IDs alphabetically to determine which to keep
            # The one with the smaller (earlier) ID is kept as original
            if current_doc['id'] < existing_doc['id']:
                # Current doc has earlier ID, so it becomes the original
                duplicate_docs.append(existing_doc)
                doc_map[doc_group_key] = current_doc
            else:
                # Existing doc remains original, current is duplicate
                duplicate_docs.append(current_doc)

    # Extract original documents from the map
    original_docs = list(doc_map.values())

    # Delete duplicates if requested
    if delete_duplicates and duplicate_docs:
        if verbose:
            print(f'Found {len(duplicate_docs)} duplicates to delete.')

        # Extract IDs of documents to delete
        doc_ids_to_delete = [doc['id'] for doc in duplicate_docs]

        # Calculate number of batches needed
        num_batches = math.ceil(len(doc_ids_to_delete) / maximum_delete_batch_size)

        # Delete in batches
        for i in range(num_batches):
            start_index = i * maximum_delete_batch_size
            end_index = min((i + 1) * maximum_delete_batch_size, len(doc_ids_to_delete))

            batch_ids = doc_ids_to_delete[start_index:end_index]

            if verbose:
                print(f'Deleting batch {i + 1} of {num_batches}...')

            bulk_delete_documents(cloud_dataset_id, batch_ids)

            if verbose:
                print(f'Batch {i + 1} deleted.')

        if verbose:
            print('All duplicate documents deleted.')
    else:
        if not duplicate_docs:
            if verbose:
                print('No duplicate documents found.')
        else:
            if verbose:
                print(f'Found {len(duplicate_docs)} duplicates, but deletion was not requested.')

    return duplicate_docs, original_docs
