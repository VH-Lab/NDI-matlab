"""List all NDI and API document IDs from a remote dataset.

Ported from: ndi.cloud.sync.internal.listRemoteDocumentIds (MATLAB)
"""

from typing import Dict, List


def list_remote_document_ids(cloud_dataset_id: str, verbose: bool = False) -> Dict[str, List[str]]:
    """List all NDI and API document IDs from a remote dataset.

    This function retrieves a complete list of documents from a specified NDI cloud
    dataset by calling a helper function that handles API result pagination.

    Args:
        cloud_dataset_id: The unique identifier of the cloud dataset
        verbose: If True, displays progress information

    Returns:
        A dictionary containing two keys:
            - 'ndi_id': List of NDI document IDs
            - 'api_id': List of the corresponding cloud API document IDs ('_id')
        The lists are ordered such that ndi_id[i] corresponds to api_id[i].

    Raises:
        RuntimeError: If the API call fails
    """
    from ndi.cloud.api.documents import list_dataset_documents_all

    if verbose:
        print(f'Fetching complete remote document list for dataset {cloud_dataset_id}...')

    try:
        # Delegate the fetching and pagination logic to the dedicated function
        _, all_documents = list_dataset_documents_all(cloud_dataset_id)

        if not all_documents:
            # Handle case where the dataset is empty
            id_map = {'ndi_id': [], 'api_id': []}
            if verbose:
                print('No remote documents found.')
            return id_map

        # Efficiently extract IDs from the full list of documents
        all_ndi_ids = [doc['ndiId'] for doc in all_documents]
        all_api_ids = [doc['id'] for doc in all_documents]

        if verbose:
            print(f'Total remote documents processed: {len(all_ndi_ids)}.')

    except Exception as e:
        raise RuntimeError(
            f'Failed to list all remote documents. Original error: {str(e)}'
        ) from e

    # Create the final output dictionary
    return {'ndi_id': all_ndi_ids, 'api_id': all_api_ids}
