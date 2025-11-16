"""Upload new local documents (and associated files) to remote.

Ported from: ndi.cloud.sync.uploadNew (MATLAB)
"""

from typing import TYPE_CHECKING

from ndi.cloud.sync.sync_options import SyncOptions
from ndi.cloud.sync.internal.list_local_documents import list_local_documents
from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids
from ndi.cloud.sync.internal.index.read_sync_index import read_sync_index
from ndi.cloud.sync.internal.index.update_sync_index import update_sync_index

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def upload_new(ndi_dataset: 'Dataset', **kwargs) -> None:
    """Upload new local documents (and associated files) to remote.

    This function implements the "UploadNew" synchronization mode.
    In this mode, it compares the current local state to the local state from the
    last sync (from a sync index) to identify newly added local documents,
    which are then uploaded.

    No remote documents are deleted by this mode.
    No local documents are deleted by this mode.

    It relies on a sync index file ([NDIDATASET.path]/.ndi/sync/index.json)
    to keep track of previously synced states and updates it after the operation.

    Args:
        ndi_dataset: The local NDI dataset object
        **kwargs: Optional synchronization options:
            - sync_files (bool): If True, files will be synced (default: True)
            - verbose (bool): If True, verbose output is printed (default: True)
            - dry_run (bool): If True, actions are simulated but not performed (default: False)
            - file_upload_strategy (str): "serial" or "batch" (default: "batch")

    See also:
        ndi.cloud.sync_dataset
        ndi.cloud.sync.SyncOptions
        ndi.cloud.sync.SyncMode
    """
    from ndi.cloud.internal.get_cloud_dataset_id_for_local_dataset import get_cloud_dataset_id_for_local_dataset
    from ndi.cloud.upload.upload_document_collection import upload_document_collection
    from ndi.cloud.sync.internal.upload_files_for_dataset_documents import upload_files_for_dataset_documents

    sync_options = SyncOptions(**kwargs)

    if sync_options.verbose:
        print(f'Syncing dataset "{ndi_dataset.path}".')
        print('Will upload new local documents to remote.')

    # Resolve cloud dataset identifier
    cloud_dataset_id = get_cloud_dataset_id_for_local_dataset(ndi_dataset)
    if sync_options.verbose:
        print(f'Using Cloud Dataset ID: {cloud_dataset_id}')

    # 1. Read sync index
    sync_index = read_sync_index(ndi_dataset)
    if sync_index is None or not sync_index.get('localDocumentIdsLastSync'):
        local_ids_last_sync = []
    else:
        local_ids_last_sync = sync_index['localDocumentIdsLastSync']

    if sync_options.verbose:
        print(f'Read sync index. Last sync recorded {len(local_ids_last_sync)} local documents.')

    # 2. Get current local state
    local_documents, local_document_ids = list_local_documents(ndi_dataset)
    if sync_options.verbose:
        print(f'Found {len(local_document_ids)} documents locally.')

    # 3. Calculate differences: documents added locally since last sync
    ndi_ids_to_upload = []
    documents_to_upload = []
    local_ids_last_sync_set = set(local_ids_last_sync)
    for i, doc_id in enumerate(local_document_ids):
        if doc_id not in local_ids_last_sync_set:
            ndi_ids_to_upload.append(doc_id)
            documents_to_upload.append(local_documents[i])

    if sync_options.verbose:
        print(f'Found {len(ndi_ids_to_upload)} documents added locally since last sync.')

    # 4. Perform upload actions
    if ndi_ids_to_upload:
        if sync_options.dry_run:
            print(f'[DryRun] Would upload {len(ndi_ids_to_upload)} documents to remote.')
            if sync_options.verbose:
                for ndi_id in ndi_ids_to_upload:
                    print(f'  [DryRun] - NDI ID: {ndi_id}')
        else:
            if sync_options.verbose:
                print(f'Uploading {len(ndi_ids_to_upload)} documents...')
            upload_document_collection(cloud_dataset_id, documents_to_upload)

            # Upload associated files if SyncFiles is true
            if sync_options.sync_files:
                if sync_options.verbose:
                    print('SyncFiles is true. Uploading associated data files...')
                upload_files_for_dataset_documents(
                    cloud_dataset_id,
                    ndi_dataset,
                    documents_to_upload,
                    verbose=sync_options.verbose,
                    file_upload_strategy=sync_options.file_upload_strategy
                )
            elif sync_options.verbose:
                print('"SyncFiles" option is false. Skipping upload of associated data files.')

            if sync_options.verbose:
                print(f'Completed uploading {len(ndi_ids_to_upload)} documents.')
    else:
        if sync_options.verbose:
            print('No new local documents to upload to remote.')

    # 5. Update sync index
    if not sync_options.dry_run:
        # Re-fetch final remote states to ensure accuracy
        final_remote_document_id_map = list_remote_document_ids(cloud_dataset_id)

        update_sync_index(
            ndi_dataset, cloud_dataset_id,
            local_document_ids=local_document_ids,
            remote_document_ids=final_remote_document_id_map['ndi_id']
        )

        if sync_options.verbose:
            print('Sync index updated.')

    if sync_options.verbose:
        print(f'Syncing complete for dataset: {ndi_dataset.path}')
