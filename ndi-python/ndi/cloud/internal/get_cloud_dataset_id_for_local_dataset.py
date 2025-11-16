"""
Retrieve the cloud dataset ID for a local NDI dataset.

This module searches for the 'dataset_remote' document in a local dataset's
database to find its cloud dataset identifier.

MATLAB Source: ndi/+ndi/+cloud/+internal/getCloudDatasetIdForLocalDataset.m
"""

from typing import Tuple, List, Optional


def get_cloud_dataset_id_for_local_dataset(ndi_dataset: 'ndi.dataset') -> Tuple[str, List]:
    """
    Retrieve the cloud dataset ID for a local dataset.

    This function searches the database of a local NDI dataset for a unique
    'dataset_remote' document. This document establishes a link between the
    local dataset and its remote counterpart in the NDI cloud.

    If a single 'dataset_remote' document is found, the function extracts and
    returns the cloud dataset's unique identifier.

    The function handles three cases:
      1. No 'dataset_remote' document is found: It returns an empty string for
         the ID and an empty list for the document.
      2. Exactly one 'dataset_remote' document is found: It returns the cloud
         dataset ID and the corresponding ndi.document object.
      3. More than one 'dataset_remote' document is found: It raises an error,
         as this indicates a misconfiguration.

    Args:
        ndi_dataset: The local NDI dataset object to search within

    Returns:
        Tuple containing:
            - cloud_dataset_id (str): The unique identifier of the remote cloud
              dataset. Returns an empty string if no 'dataset_remote' document is found.
            - cloud_dataset_id_document (List): A list containing the 'dataset_remote'
              document object. Returns an empty list if no document is found.

    Raises:
        RuntimeError: If more than one 'dataset_remote' document is found

    Example:
        >>> from ndi.cloud.internal import get_cloud_dataset_id_for_local_dataset
        >>> # Assume my_dataset is a valid ndi.dataset object
        >>> cloud_id, cloud_doc = get_cloud_dataset_id_for_local_dataset(my_dataset)
        >>> if not cloud_id:
        ...     print('This local dataset is not linked to a cloud dataset.')
        ... else:
        ...     print(f'Cloud dataset ID: {cloud_id}')

    See Also:
        create_remote_dataset_doc

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/getCloudDatasetIdForLocalDataset.m
    """
    from ndi.query import query

    # Create a query to find 'dataset_remote' documents
    cloud_dataset_id_query = query('', isa='dataset_remote')
    cloud_dataset_id_document = ndi_dataset.database_search(cloud_dataset_id_query)

    if len(cloud_dataset_id_document) > 1:
        raise RuntimeError(
            f'NDICloud:Sync:MultipleCloudDatasetId - '
            f'Found more than one remote cloudDatasetId for the local '
            f'dataset: {ndi_dataset.path}'
        )
    elif cloud_dataset_id_document:
        # Extract the cloud dataset ID from the document
        cloud_dataset_id = cloud_dataset_id_document[0].document_properties['dataset_remote']['dataset_id']
    else:
        cloud_dataset_id = ''

    return cloud_dataset_id, cloud_dataset_id_document
