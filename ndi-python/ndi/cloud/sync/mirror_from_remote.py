"""Mirror the remote dataset to the local dataset.

Ported from: ndi.cloud.sync.mirrorFromRemote (MATLAB)
"""

from typing import TYPE_CHECKING

from ndi.cloud.sync.sync_options import SyncOptions
from ndi.cloud.sync.internal.list_local_documents import list_local_documents
from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids
from ndi.cloud.sync.internal.download_ndi_documents import download_ndi_documents
from ndi.cloud.sync.internal.delete_local_documents import delete_local_documents
from ndi.cloud.sync.internal.index.update_sync_index import update_sync_index

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def mirror_from_remote(ndi_dataset: 'Dataset', **kwargs) -> None:
    """Mirror the remote dataset to the local dataset.

    This function implements the "MirrorFromRemote" synchronization mode.
    It ensures the local dataset becomes an exact representation of the
    remote dataset by:
    1. Downloading any documents present on the remote but not locally.
    2. Deleting any local documents that are not present on the remote.

    The remote dataset is not modified by this operation.
    The local dataset is modified (additions and deletions).

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

    sync_options = SyncOptions(**kwargs)

    if sync_options.verbose:
        print(f'Syncing dataset "{ndi_dataset.path}".')
        print('Mode: MirrorFromRemote. Local will be made a mirror of remote.')

    # Resolve cloud dataset identifier
    cloud_dataset_id = get_cloud_dataset_id_for_local_dataset(ndi_dataset)
    if sync_options.verbose:
        print(f'Using Cloud Dataset ID: {cloud_dataset_id}')

    # --- Phase 1: Get initial states ---
    _, initial_local_document_ids = list_local_documents(ndi_dataset)
    initial_remote_document_id_map = list_remote_document_ids(cloud_dataset_id)

    if sync_options.verbose:
        print(f'Initial state: {len(initial_local_document_ids)} local documents, '
              f'{len(initial_remote_document_id_map["ndi_id"])} remote documents.')

    # --- Phase 2: Download missing documents from remote ---
    ndi_ids_to_download = []
    cloud_api_ids_to_download = []
    local_ndi_ids_set = set(initial_local_document_ids)
    for i, ndi_id in enumerate(initial_remote_document_id_map['ndi_id']):
        if ndi_id not in local_ndi_ids_set:
            ndi_ids_to_download.append(ndi_id)
            cloud_api_ids_to_download.append(initial_remote_document_id_map['api_id'][i])

    if ndi_ids_to_download:
        if sync_options.verbose:
            print(f'Found {len(ndi_ids_to_download)} documents on remote to download to local.')

        if sync_options.dry_run:
            print(f'[DryRun] Would download {len(ndi_ids_to_download)} documents from remote.')
            if sync_options.verbose:
                for i, ndi_id in enumerate(ndi_ids_to_download):
                    print(f'  [DryRun] - Download NDI ID: {ndi_id} '
                          f'(Cloud API ID: {cloud_api_ids_to_download[i]})')
        else:
            download_ndi_documents(cloud_dataset_id, cloud_api_ids_to_download,
                                   ndi_dataset, sync_options)
            if sync_options.verbose:
                print('Completed download phase.')
    elif sync_options.verbose:
        print('No new documents to download from remote.')

    # --- Phase 3: Delete local documents not present on remote ---
    # Re-list local documents as they might have changed after downloads
    _, local_document_ids_after_download = list_local_documents(ndi_dataset)

    # Documents to delete are those now local but NOT in the *initial* remote list
    local_ids_to_delete = []
    remote_ndi_ids_set = set(initial_remote_document_id_map['ndi_id'])
    for doc_id in local_document_ids_after_download:
        if doc_id not in remote_ndi_ids_set:
            local_ids_to_delete.append(doc_id)

    if local_ids_to_delete:
        if sync_options.verbose:
            print(f'Found {len(local_ids_to_delete)} local documents to delete '
                  f'(not on remote).')

        if sync_options.dry_run:
            print(f'[DryRun] Would delete {len(local_ids_to_delete)} local documents.')
            if sync_options.verbose:
                for doc_id in local_ids_to_delete:
                    print(f'  [DryRun] - Delete Local NDI ID: {doc_id}')
        else:
            delete_local_documents(ndi_dataset, local_ids_to_delete, sync_options)
            if sync_options.verbose:
                print('Completed local deletion phase.')
    elif sync_options.verbose:
        print('No local documents to delete.')

    # --- Phase 4: Update sync index ---
    if not sync_options.dry_run:
        # Update local state after update. Remote was not changed by this mode
        _, final_local_document_ids = list_local_documents(ndi_dataset)

        update_sync_index(
            ndi_dataset, cloud_dataset_id,
            local_document_ids=final_local_document_ids,
            remote_document_ids=initial_remote_document_id_map['ndi_id']
        )

        if sync_options.verbose:
            print('Sync index updated.')
    else:
        if sync_options.verbose:
            print('[DryRun] Sync index would have been updated.')

    if sync_options.verbose:
        print(f'"MirrorFromRemote" sync completed for dataset: {ndi_dataset.path}')
