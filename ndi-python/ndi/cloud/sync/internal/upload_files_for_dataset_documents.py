"""Upload a set of files belonging to a set of dataset documents.

Ported from: ndi.cloud.sync.internal.uploadFilesForDatasetDocuments (MATLAB)
"""

from typing import List, Tuple, Literal, TYPE_CHECKING

from ndi.cloud.sync.internal.files_not_yet_uploaded import files_not_yet_uploaded

if TYPE_CHECKING:
    from ndi.dataset import Dataset
    from ndi.document import Document


def upload_files_for_dataset_documents(
    cloud_dataset_id: str,
    ndi_dataset: 'Dataset',
    dataset_documents: List['Document'],
    verbose: bool = True,
    file_upload_strategy: Literal["serial", "batch"] = "batch",
    only_missing: bool = True
) -> Tuple[bool, str]:
    """Upload a set of files belonging to a set of dataset documents.

    Uploads a set of files that are associated with a given list of NDI_DOCUMENTS.

    This function takes a list of NDI_DOCUMENTS, finds all the associated binary
    data files that are stored in the NDIDATASET, and uploads them to the remote
    dataset identified by CLOUD_DATASET_ID.

    Args:
        cloud_dataset_id: The ID of the dataset on the cloud
        ndi_dataset: The local NDI dataset object
        dataset_documents: List of document objects
        verbose: Display verbose output (default: True)
        file_upload_strategy: Upload strategy - "serial" to upload files one by
            one or "batch" (default) to upload bundles of files using zip files.
            The "batch" option is recommended when uploading many files, and the
            serial option can be used as a fallback if batch upload fails.
        only_missing: Only upload missing files (default: True)

    Returns:
        A tuple containing:
            - success: True if all files were uploaded successfully
            - message: An error message if success is False
    """
    from ndi.database.internal import list_binary_files
    from ndi.cloud import upload_single_file
    from ndi.cloud.upload.zip_for_upload import zip_for_upload

    success = True
    message = ''

    file_manifest = list_binary_files(ndi_dataset, dataset_documents, verbose)

    # Initialize is_uploaded to False
    for item in file_manifest:
        item['is_uploaded'] = False

    if verbose:
        print(f'{len(file_manifest)} files in the manifest.')

    if only_missing:
        file_manifest, message = files_not_yet_uploaded(file_manifest, cloud_dataset_id)
        if message:
            success = False
            return success, message

    if verbose:
        print(f'{len(file_manifest)} files still need to be uploaded.')

    if not file_manifest:
        message = 'All files are already on the remote.'
        return success, message

    total_size_kb = sum(item['bytes'] for item in file_manifest) / 1e3

    if file_upload_strategy == "serial":
        # Import progress bar if available
        try:
            from ndi.gui.component import ProgressBarWindow
            from did.ido import unique_id

            app = ProgressBarWindow('NDI tasks')
            uuid = unique_id()
            app.add_bar(label='Uploading document-associated binary files', tag=uuid, auto=True)

            for i, file_item in enumerate(file_manifest):
                if not file_item['is_uploaded']:
                    upload_success, upload_message = upload_single_file(
                        cloud_dataset_id,
                        file_item['uid'],
                        file_item['file_path']
                    )
                    if not upload_success:
                        if success:
                            message = f"Failed to upload file {file_item['uid']}: {upload_message}"
                        success = False

                app.update_bar(uuid, (i + 1) / len(file_manifest))
        except ImportError:
            # Progress bar not available, just upload without progress
            for file_item in file_manifest:
                if not file_item['is_uploaded']:
                    upload_success, upload_message = upload_single_file(
                        cloud_dataset_id,
                        file_item['uid'],
                        file_item['file_path']
                    )
                    if not upload_success:
                        if success:
                            message = f"Failed to upload file {file_item['uid']}: {upload_message}"
                        success = False

    elif file_upload_strategy == "batch":
        batch_success, batch_message = zip_for_upload(
            ndi_dataset, file_manifest, total_size_kb, cloud_dataset_id
        )
        if not batch_success:
            success = False
            message = batch_message

    return success, message
