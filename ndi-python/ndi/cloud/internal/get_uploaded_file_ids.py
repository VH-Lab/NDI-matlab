"""
Get a list of file UIDs that have been uploaded to the cloud.

This module retrieves all files in a cloud dataset and filters for those
that have been successfully uploaded.

MATLAB Source: ndi/+ndi/+cloud/+internal/getUploadedFileIds.m
"""

from typing import List


def get_uploaded_file_ids(dataset_id: str) -> List[str]:
    """
    Get a list of uploaded file UIDs for a cloud dataset.

    This function retrieves a list of all datasets from the cloud, finds the
    one matching the given dataset_id, and then returns the UIDs of all files
    within that dataset that have been successfully uploaded.

    The function iterates through the list of all available datasets to find a
    match. If no dataset with the specified ID is found, an error is raised.

    Once the correct dataset is identified, it filters the files to include only
    those marked as 'uploaded' and returns their UIDs.

    Args:
        dataset_id: The unique identifier of the cloud dataset

    Returns:
        A list containing the UIDs of all successfully uploaded files in the
        dataset. Returns an empty list if no files have been uploaded.

    Raises:
        RuntimeError: If the dataset is not found or if the API call fails

    Example:
        >>> from ndi.cloud.internal import get_uploaded_file_ids
        >>> # Assume 'd-12345' is a valid cloud dataset ID
        >>> file_ids = get_uploaded_file_ids('d-12345')
        >>> print(f'Found {len(file_ids)} uploaded files.')

    See Also:
        ndi.cloud.api.datasets.list_datasets

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/getUploadedFileIds.m
    """
    from ndi.cloud.api.datasets import list_datasets

    try:
        # Get all datasets from the cloud
        success, _, datasets = list_datasets()

        if not success:
            raise RuntimeError("Failed to list datasets from cloud")

        # Find the dataset matching the given ID
        dataset = None
        for ds in datasets:
            if ds.get('id') == dataset_id:
                dataset = ds
                break

        if dataset is None:
            raise RuntimeError(f'No dataset found with id "{dataset_id}"')

    except Exception as e:
        raise RuntimeError(f"Error retrieving dataset: {str(e)}") from e

    # Extract UIDs of uploaded files
    file_ids = []
    if 'files' in dataset and dataset['files']:
        # Filter for uploaded files and extract their UIDs
        for file_info in dataset['files']:
            if file_info.get('uploaded', False):
                file_ids.append(file_info.get('uid'))

    return file_ids
