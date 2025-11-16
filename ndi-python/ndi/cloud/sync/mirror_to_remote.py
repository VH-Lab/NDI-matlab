"""Mirror the local dataset to the remote dataset.

Ported from: ndi.cloud.sync.mirrorToRemote (MATLAB)
"""

from typing import TYPE_CHECKING

from ndi.cloud.sync.sync_options import SyncOptions
from ndi.cloud.sync.internal.list_local_documents import list_local_documents
from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids
from ndi.cloud.sync.internal.delete_remote_documents import delete_remote_documents
from ndi.cloud.sync.internal.index.update_sync_index import update_sync_index

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def mirror_to_remote(ndi_dataset: 'Dataset', **kwargs) -> None:
    """Mirror the local dataset to the remote dataset.

    This function implements the "MirrorToRemote" synchronization mode.
    It ensures the remote dataset becomes an exact representation of the
    local dataset by:
    1. Uploading any documents present locally but not on the remote.
    2. Deleting any remote documents that are not present locally.

    The local dataset is not modified by this operation.
    The remote dataset is modified (additions and deletions).

    It relies on a sync index file ([NDIDATASET.path]/.ndi/sync/index.json)
    and updates it after the operation.

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
        print('Mode: MirrorToRemote. Remote will be made a mirror of local.')

    # Resolve cloud dataset identifier
    cloud_dataset_id = get_cloud_dataset_id_for_local_dataset(ndi_dataset)
    if sync_options.verbose:
        print(f'Using Cloud Dataset ID: {cloud_dataset_id}')

    # --- Phase 1: Get Initial States ---
    initial_local_documents, initial_local_document_ids = list_local_documents(ndi_dataset)
    initial_remote_document_id_map = list_remote_document_ids(cloud_dataset_id)

    if sync_options.verbose:
        print(f'Initial state: {len(initial_local_document_ids)} local documents, '
              f'{len(initial_remote_document_id_map["ndi_id"])} remote documents.')

    # --- Phase 2: Upload missing documents to remote ---
    ndi_ids_to_upload = []
    documents_to_upload = []
    remote_ndi_ids_set = set(initial_remote_document_id_map['ndi_id'])
    for i, doc_id in enumerate(initial_local_document_ids):
        if doc_id not in remote_ndi_ids_set:
            ndi_ids_to_upload.append(doc_id)
            documents_to_upload.append(initial_local_documents[i])

    if ndi_ids_to_upload:
        if sync_options.verbose:
            print(f'Found {len(ndi_ids_to_upload)} local documents to upload to remote.')

        if sync_options.dry_run:
            print(f'[DryRun] Would upload {len(ndi_ids_to_upload)} documents to remote.')
            if sync_options.verbose:
                for ndi_id in ndi_ids_to_upload:
                    print(f'  [DryRun] - Upload NDI ID: {ndi_id}')
        else:
            upload_document_collection(cloud_dataset_id, documents_to_upload)
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
                print('Completed upload phase.')
    elif sync_options.verbose:
        print('No new local documents to upload to remote.')

    # --- Phase 3: Delete remote documents not present locally ---
    # Re-list remote documents as they might have changed after uploads
    remote_document_id_map_after_upload = list_remote_document_ids(cloud_dataset_id)

    # Documents to delete are those now remote but NOT in the *initial* local list
    remote_ndi_ids_to_delete = []
    cloud_api_ids_to_delete = []
    local_ndi_ids_set = set(initial_local_document_ids)
    for i, ndi_id in enumerate(remote_document_id_map_after_upload['ndi_id']):
        if ndi_id not in local_ndi_ids_set:
            remote_ndi_ids_to_delete.append(ndi_id)
            cloud_api_ids_to_delete.append(remote_document_id_map_after_upload['api_id'][i])

    if remote_ndi_ids_to_delete:
        if sync_options.verbose:
            print(f'Found {len(remote_ndi_ids_to_delete)} remote documents to delete '
                  f'(not on local).')

        if sync_options.dry_run:
            print(f'[DryRun] Would delete {len(cloud_api_ids_to_delete)} remote documents.')
            if sync_options.verbose:
                for i, api_id in enumerate(cloud_api_ids_to_delete):
                    print(f'  [DryRun] - Delete Remote API ID: {api_id} '
                          f'(corresponds to NDI ID: {remote_ndi_ids_to_delete[i]})')
        else:
            delete_remote_documents(cloud_dataset_id, cloud_api_ids_to_delete, sync_options)
            if sync_options.verbose:
                print('Completed remote deletion phase.')
    elif sync_options.verbose:
        print('No remote documents to delete.')

    # --- Phase 4: Update sync index ---
    if not sync_options.dry_run:
        # Update remote state after update. Local was not changed by this mode
        final_remote_document_id_map = list_remote_document_ids(cloud_dataset_id)

        update_sync_index(
            ndi_dataset, cloud_dataset_id,
            local_document_ids=initial_local_document_ids,
            remote_document_ids=final_remote_document_id_map['ndi_id']
        )

        if sync_options.verbose:
            print('Sync index updated.')
    else:
        if sync_options.verbose:
            print('[DryRun] Sync index would have been updated.')

    if sync_options.verbose:
        print(f'"MirrorToRemote" sync completed for dataset: {ndi_dataset.path}')
