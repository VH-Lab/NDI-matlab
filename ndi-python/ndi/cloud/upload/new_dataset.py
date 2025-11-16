"""
Create a new dataset in NDI Cloud.

This module provides functionality to upload a new NDI dataset to the cloud,
including metadata creation and initial data upload.

MATLAB Source: ndi/+ndi/+cloud/+upload/newDataset.m
"""

from typing import Optional, Tuple


def new_dataset(dataset: 'ndi.dataset') -> str:
    """
    Upload a new dataset to NDI Cloud.

    This function creates a new dataset record on NDI Cloud by converting the
    local ndi.dataset object to metadata, creating the cloud dataset record,
    and uploading the initial data.

    Args:
        dataset: An ndi.dataset object to be uploaded to NDI Cloud

    Returns:
        dataset_id: The unique identifier for the dataset on NDI Cloud

    Raises:
        RuntimeError: If dataset creation or upload fails
        TypeError: If dataset is not an ndi.dataset object

    Example:
        >>> from ndi.cloud.upload import new_dataset
        >>> # Assuming D is a valid ndi.dataset object
        >>> dataset_id = new_dataset(D)
        >>> print(f"Dataset uploaded with ID: {dataset_id}")

    Note:
        This function performs two main steps:
        1. Creates the dataset record on NDI Cloud and inserts the metadata
        2. Uploads the dataset documents and files to the cloud

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+upload/newDataset.m
    """
    # TODO: Implement type checking for ndi.dataset
    # In MATLAB: arguments D (1,1) {mustBeA(D,'ndi.dataset')} end

    # Step 1: Create the dataset record on NDI Cloud and insert the metadata
    # Step 1a: Create metadata from the dataset

    # TODO: Implement ndidataset2metadataeditorstruct function
    # This should be added to ndi.database.metadata_ds_core module
    # MATLAB code:
    # metadata_structure = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(D)

    metadata_structure = {}  # Placeholder
    print("WARNING: ndidataset2metadataeditorstruct not yet implemented. "
          "Using empty metadata structure.")

    # Step 1b: Create the dataset record on NDI cloud

    # TODO: Implement createCloudMetadataStruct function
    # This should be added to ndi.cloud.utility module
    # MATLAB code:
    # [status, response, dataset_id] = ndi.cloud.utility.createCloudMetadataStruct(metadata_structure)

    # Placeholder implementation
    dataset_id = "placeholder_dataset_id"
    print("WARNING: createCloudMetadataStruct not yet implemented. "
          "Using placeholder dataset ID.")

    # MATLAB code for reference:
    # [status, response, dataset_id] = ndi.cloud.utility.createCloudMetadataStruct(metadata_structure)
    # if not status:
    #     raise RuntimeError(f"Failed to create cloud metadata: {response}")

    # Step 2: Upload the dataset documents and files

    # TODO: Implement upload_to_ndicloud function (will be in upload_to_ndicloud.py)
    # from .upload_to_ndicloud import upload_to_ndicloud
    # success, msg = upload_to_ndicloud(dataset, dataset_id)
    # if not success:
    #     raise RuntimeError(f"Failed to upload dataset: {msg}")

    print(f"WARNING: upload_to_ndicloud not yet called. "
          f"Dataset creation incomplete.")

    return dataset_id
