"""Perform a bidirectional additive synchronization.

Ported from: ndi.cloud.sync.twoWaySync (MATLAB)
"""

from typing import TYPE_CHECKING

from ndi.cloud.sync.sync_options import SyncOptions
from ndi.cloud.sync.internal.list_local_documents import list_local_documents
from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids
from ndi.cloud.sync.internal.download_ndi_documents import download_ndi_documents
from ndi.cloud.sync.internal.index.update_sync_index import update_sync_index

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def two_way_sync(ndi_dataset: 'Dataset', **kwargs) -> None:
    """Perform a bidirectional additive synchronization.

    This function implements the "TwoWaySync" synchronization mode.
    It ensures that both local and remote datasets are updated with
    documents from the other, without deleting any documents.
    1. Uploads any documents present locally but not on the remote.
    2. Downloads any documents present on the remote but not locally.

    Both local and remote datasets may be modified (additions only).

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
        print('Mode: TwoWaySync. Performing bidirectional additive sync.')

    # Resolve cloud dataset identifier
    cloud_dataset_id = get_cloud_dataset_id_for_local_dataset(ndi_dataset)
    if sync_options.verbose:
        print(f'Using Cloud Dataset ID: {cloud_dataset_id}')

    # --- Phase 1: Get Initial States ---
    initial_local_documents, initial_local_document_ids = list_local_documents(ndi_dataset)
    initial_remote_document_id_map = list_remote_document_ids(cloud_dataset_id)  # dict: ndi_id, api_id

    if sync_options.verbose:
        print(f'Initial state: {len(initial_local_document_ids)} local documents, '
              f'{len(initial_remote_document_id_map["ndi_id"])} remote documents.')

    # --- Phase 2: Upload local-only documents to remote ---
    if not initial_remote_document_id_map['ndi_id']:
        ndi_ids_to_upload = initial_local_document_ids
        documents_to_upload = initial_local_documents
    else:
        # Find documents in local but not in remote
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
                    print(f'SyncFiles is true. Uploading associated data files for '
                          f'{len(documents_to_upload)} documents...')
                upload_files_for_dataset_documents(
                    cloud_dataset_id,
                    ndi_dataset,
                    documents_to_upload,
                    verbose=sync_options.verbose,
                    file_upload_strategy=sync_options.file_upload_strategy
                )
            elif sync_options.verbose:
                print('SyncFiles is false. Skipping upload of associated data files.')

            if sync_options.verbose:
                print('Completed upload phase.')
    elif sync_options.verbose:
        print('No new local documents to upload to remote.')

    # --- Phase 3: Download remote-only documents to local ---
    # Re-list remote state as it might have changed due to uploads
    remote_document_id_map_after_upload = list_remote_document_ids(cloud_dataset_id)

    # Find documents in remote but not in local
    ndi_ids_to_download = []
    cloud_api_ids_to_download = []
    local_ndi_ids_set = set(initial_local_document_ids)
    for i, ndi_id in enumerate(remote_document_id_map_after_upload['ndi_id']):
        if ndi_id not in local_ndi_ids_set:
            ndi_ids_to_download.append(ndi_id)
            cloud_api_ids_to_download.append(remote_document_id_map_after_upload['api_id'][i])

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

    # --- Phase 4: Update sync index ---
    if not sync_options.dry_run:
        # Get final states. Both sides changed
        _, final_local_document_ids = list_local_documents(ndi_dataset)
        final_remote_document_id_map = list_remote_document_ids(cloud_dataset_id)

        update_sync_index(
            ndi_dataset, cloud_dataset_id,
            local_document_ids=final_local_document_ids,
            remote_document_ids=final_remote_document_id_map['ndi_id']
        )

        if sync_options.verbose:
            print('Sync index updated.')
    else:
        if sync_options.verbose:
            print('[DryRun] Sync index would have been updated.')

    if sync_options.verbose:
        print(f'"TwoWaySync" sync completed for dataset: {ndi_dataset.path}')
