"""
Create an NDI document linking a local dataset to a remote cloud dataset.

This module creates a 'dataset_remote' document that establishes the connection
between a local NDI dataset and its cloud counterpart.

MATLAB Source: ndi/+ndi/+cloud/+internal/createRemoteDatasetDoc.m
"""

from typing import Optional


def create_remote_dataset_doc(
    cloud_dataset_id: str,
    ndi_dataset: 'ndi.dataset',
    replace_existing: bool = False
) -> 'ndi.document':
    """
    Create an NDI document with remote dataset details.

    Creates a 'dataset_remote' NDI document, which links a local NDI dataset
    to a remote cloud dataset.

    This function first checks if a 'dataset_remote' document already exists
    for the given local dataset. If one is found, it will be replaced if
    'replace_existing' is True; otherwise, the function will raise an error.

    After ensuring no existing document is present (or removing it), the
    function fetches the metadata for the specified cloud dataset from the
    remote server. It then uses this information to create a new
    'dataset_remote' document in memory. This new document contains the cloud
    dataset ID and the organization ID.

    NOTE: This function only creates the document in memory. The calling
    function is responsible for adding it to the database if desired.

    Args:
        cloud_dataset_id: The unique identifier for the cloud dataset
        ndi_dataset: The local NDI dataset object to be associated with the
            cloud dataset
        replace_existing: If True, any existing 'dataset_remote' document for
            the local dataset will be removed before creating the new one.
            Defaults to False.

    Returns:
        A new 'dataset_remote' ndi.document object containing the remote
        dataset ID and organization ID

    Raises:
        RuntimeError: If an existing 'dataset_remote' document is found and
            replace_existing is False, or if the cloud dataset cannot be fetched
        ValueError: If the cloud dataset ID is invalid

    Example:
        >>> from ndi.cloud.internal import create_remote_dataset_doc
        >>> # Assume my_dataset is a valid ndi.dataset object and a cloud dataset
        >>> # with ID 'd-12345' exists
        >>> new_doc = create_remote_dataset_doc('d-12345', my_dataset)
        >>> my_dataset.database_add(new_doc)  # Add the document to the database

    See Also:
        get_cloud_dataset_id_for_local_dataset

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/createRemoteDatasetDoc.m
    """
    from ndi.document import document
    from ndi.cloud.api.datasets import get_dataset
    from .get_cloud_dataset_id_for_local_dataset import get_cloud_dataset_id_for_local_dataset

    # Check if a remote dataset document already exists
    _, existing_doc = get_cloud_dataset_id_for_local_dataset(ndi_dataset)

    if existing_doc:
        if replace_existing:
            # Remove the existing document
            ndi_dataset.database_rm(existing_doc[0].id())
        else:
            raise RuntimeError(
                "An existing remote dataset document was found. "
                "Use 'replace_existing=True' to replace it."
            )

    # Fetch the cloud dataset metadata
    success, remote_dataset = get_dataset(cloud_dataset_id)
    if not success:
        error_msg = remote_dataset.get('message', 'Unknown error')
        raise RuntimeError(f'Failed to get dataset: {error_msg}')

    # Create the 'dataset_remote' document
    remote_dataset_doc = document(
        doc_type='dataset_remote',
        base_session_id=ndi_dataset.id,
        dataset_remote={
            'dataset_id': remote_dataset.get('id', cloud_dataset_id),
            'organization_id': remote_dataset.get('organizationId', '')
        }
    )

    return remote_dataset_doc
