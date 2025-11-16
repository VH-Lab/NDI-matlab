"""Download new documents (and associated data files) from remote to local.

Ported from: ndi.cloud.sync.downloadNew (MATLAB)
"""

from typing import TYPE_CHECKING

from ndi.cloud.sync.sync_options import SyncOptions
from ndi.cloud.sync.internal.list_local_documents import list_local_documents
from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids
from ndi.cloud.sync.internal.download_ndi_documents import download_ndi_documents
from ndi.cloud.sync.internal.index.read_sync_index import read_sync_index
from ndi.cloud.sync.internal.index.update_sync_index import update_sync_index

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def download_new(ndi_dataset: 'Dataset', **kwargs) -> None:
    """Download new documents (and associated data files) from remote to local.

    This function implements the "DownloadNew" synchronization mode.
    It identifies documents present on the remote cloud storage that are
    not present in the local NDI dataset and downloads them.

    No local documents are deleted or modified.
    No remote documents are deleted or modified.

    It relies on a sync index file ([NDIDATASET.path]/.ndi/sync/index.json)
    to keep track of previously synced states, though for "DownloadNew"
    mode, it compares the current remote state to the remote state from the
    last sync (from the index) to identify newly added remote documents.
    The index is updated after the operation.

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
        print('Will download new documents from remote.')

    # Resolve cloud dataset identifier
    cloud_dataset_id = get_cloud_dataset_id_for_local_dataset(ndi_dataset)
    if sync_options.verbose:
        print(f'Using Cloud Dataset ID: {cloud_dataset_id}')

    # 1. Read sync index
    sync_index = read_sync_index(ndi_dataset)
    if sync_index is None or not sync_index.get('remoteDocumentIdsLastSync'):
        remote_ids_last_sync = []
    else:
        remote_ids_last_sync = sync_index['remoteDocumentIdsLastSync']

    if sync_options.verbose:
        print(f'Read sync index. Last sync recorded {len(remote_ids_last_sync)} remote documents.')

    # 2. Get current remote state - Returns dict with ndi_id, api_id
    remote_document_id_map = list_remote_document_ids(cloud_dataset_id)
    current_remote_ndi_ids = remote_document_id_map['ndi_id']

    # 3. Calculate differences: documents added to remote since last sync
    ndi_ids_to_download = []
    cloud_api_ids_to_download = []
    remote_ids_last_sync_set = set(remote_ids_last_sync)
    for i, ndi_id in enumerate(current_remote_ndi_ids):
        if ndi_id not in remote_ids_last_sync_set:
            ndi_ids_to_download.append(ndi_id)
            cloud_api_ids_to_download.append(remote_document_id_map['api_id'][i])

    if sync_options.verbose:
        print(f'Found {len(ndi_ids_to_download)} documents added on remote since last sync.')

    # 4. Perform download actions
    if ndi_ids_to_download:
        if sync_options.dry_run:
            print(f'[DryRun] Would download {len(ndi_ids_to_download)} documents from remote.')
            if sync_options.verbose:
                for i, ndi_id in enumerate(ndi_ids_to_download):
                    print(f'  [DryRun] - NDI ID: {ndi_id} '
                          f'(Cloud Specific ID: {cloud_api_ids_to_download[i]})')
        else:
            if sync_options.verbose:
                print(f'Downloading {len(ndi_ids_to_download)} documents...')

            # This internal function handles batch download and adding to ndiDataset,
            # respecting sync_options.sync_files and sync_options.verbose internally.
            download_ndi_documents(
                cloud_dataset_id, cloud_api_ids_to_download, ndi_dataset, sync_options
            )

            if sync_options.verbose:
                print(f'Completed downloading {len(ndi_ids_to_download)} documents.')
    else:
        if sync_options.verbose:
            print('No new documents to download from remote.')

    # 5. Update sync index
    if not sync_options.dry_run:
        # Update local state after download
        _, final_local_document_ids = list_local_documents(ndi_dataset)

        update_sync_index(
            ndi_dataset, cloud_dataset_id,
            local_document_ids=final_local_document_ids,
            remote_document_ids=remote_document_id_map['ndi_id']
        )

        if sync_options.verbose:
            print('Sync index updated.')

    if sync_options.verbose:
        print(f'Syncing complete for dataset: {ndi_dataset.path}')
