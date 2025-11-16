"""Download a collection of NDI documents and their files.

Ported from: ndi.cloud.sync.internal.downloadNdiDocuments (MATLAB)
"""

import os
from typing import List, Optional, TYPE_CHECKING

from ndi.cloud.sync.internal.constants import Constants
from ndi.cloud.sync.internal.get_file_uids_from_documents import get_file_uids_from_documents
from ndi.cloud.sync.internal.update_file_info_for_local_files import update_file_info_for_local_files
from ndi.cloud.sync.internal.update_file_info_for_remote_files import update_file_info_for_remote_files

if TYPE_CHECKING:
    from ndi.dataset import Dataset
    from ndi.document import Document
    from ndi.cloud.sync.sync_options import SyncOptions


def download_ndi_documents(
    cloud_dataset_id: str,
    cloud_document_ids: List[str],
    ndi_dataset: Optional['Dataset'] = None,
    sync_options: Optional['SyncOptions'] = None
) -> List['Document']:
    """Download a collection of NDI documents and their files.

    This function downloads document metadata from the cloud, and if
    sync_options.sync_files is True, it also downloads the associated data files
    to a local staging location and updates document file information.
    Finally, it adds the documents to the local NDI dataset if provided.

    Args:
        cloud_dataset_id: The ID of the dataset on the cloud
        cloud_document_ids: A list of cloud-specific document IDs to download
        ndi_dataset: The local NDI dataset object (optional)
        sync_options: Synchronization options (optional)

    Returns:
        A list of the ndi.document objects that were downloaded and added
        to the dataset
    """
    from ndi.cloud.download.download_document_collection import download_document_collection
    from ndi.cloud.download.download_dataset_files import download_dataset_files
    from ndi.docs import docfun

    if sync_options is None:
        from ndi.cloud.sync.sync_options import SyncOptions
        sync_options = SyncOptions()

    downloaded_ndi_documents = []

    if not cloud_document_ids:
        if sync_options.verbose:
            print('No document IDs provided to download.')
        return downloaded_ndi_documents

    if sync_options.verbose:
        if not cloud_document_ids or cloud_document_ids == [""]:
            print('Attempting to download all documents...')
        else:
            print(f'Attempting to download {len(cloud_document_ids)} documents...')

    # 1. Download documents
    # This function should return a list of ndi.document objects
    new_ndi_documents = download_document_collection(cloud_dataset_id, cloud_document_ids)

    if not new_ndi_documents:
        print('Warning: No documents were retrieved from the cloud for the given IDs.')
        return downloaded_ndi_documents

    if sync_options.verbose:
        print(f'Successfully retrieved metadata for {len(new_ndi_documents)} documents.')

    # 2. Handle associated data files
    if sync_options.sync_files:
        if sync_options.verbose:
            print('SyncFiles is true. Processing associated data files...')

        if ndi_dataset is None:
            import tempfile
            root_files_folder = tempfile.gettempdir()
        else:
            root_files_folder = ndi_dataset.path

        # Todo: Ensure proper cleanup if anything goes wrong before files
        # are ingested to database.
        files_target_folder = os.path.join(root_files_folder, Constants.FILE_SYNC_LOCATION)

        file_uids_to_download = get_file_uids_from_documents(new_ndi_documents)

        if file_uids_to_download:
            if sync_options.verbose:
                print(f'Found {len(file_uids_to_download)} unique file UIDs to '
                      f'download for these documents.')
                print(f'Ensuring download directory exists: {files_target_folder}')

            if not os.path.isdir(files_target_folder):
                os.makedirs(files_target_folder, exist_ok=True)

            # This function should download files to the files_target_folder
            download_dataset_files(
                cloud_dataset_id,
                files_target_folder,
                file_uids_to_download,
                verbose=sync_options.verbose
            )

            if sync_options.verbose:
                print('Completed downloading data files.')

            # Update document file info to point to local files
            if sync_options.verbose:
                print('Updating document file info to point to local files.')
        else:
            if sync_options.verbose:
                print('No associated files found for these documents, or files '
                      'already local.')
                print('Updating document file info (SyncMode.Local, but no new '
                      'files to point to).')

        document_update_fcn = lambda doc: update_file_info_for_local_files(
            doc, files_target_folder
        )
    else:
        if sync_options.verbose:
            print('"SyncFiles" option is false. Updating document file info to '
                  'reflect remote files.')

        document_update_fcn = lambda doc: update_file_info_for_remote_files(
            doc, cloud_dataset_id
        )

    # 3. Update file info for documents based on local / remote location
    new_ndi_documents = docfun(document_update_fcn, new_ndi_documents)

    # 4. Add documents to the local dataset
    if ndi_dataset is not None:
        if sync_options.verbose:
            print(f'Adding {len(new_ndi_documents)} processed documents to the '
                  f'local dataset...')
        ndi_dataset.database_add(new_ndi_documents)
        if sync_options.verbose:
            print('Documents added to the dataset.')

    return new_ndi_documents
