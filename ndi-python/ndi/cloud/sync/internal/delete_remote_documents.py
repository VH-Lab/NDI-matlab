"""Delete specified documents from the remote cloud storage.

Ported from: ndi.cloud.sync.internal.deleteRemoteDocuments (MATLAB)
"""

from typing import List, TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.cloud.sync.sync_options import SyncOptions


def delete_remote_documents(
    cloud_dataset_id: str,
    remote_api_ids_to_delete: List[str],
    sync_options: 'SyncOptions'
) -> None:
    """Delete specified documents from the remote cloud storage.

    This function iterates through the provided API document IDs and calls
    an NDI cloud API function to remove each document from the remote storage.
    It respects the dry_run option in sync_options.

    Args:
        cloud_dataset_id: The ID of the NDI dataset on the cloud
        remote_api_ids_to_delete: A list of cloud-provider-specific API
            document IDs to delete from the remote storage
        sync_options: Synchronization options, primarily for dry_run and
            verbose flags
    """
    from ndi.cloud.api.documents import bulk_delete_documents

    if not remote_api_ids_to_delete:
        if sync_options.verbose:
            print('No remote document API IDs provided for deletion.')
        return

    if sync_options.verbose:
        print(f'Attempting to delete {len(remote_api_ids_to_delete)} documents from '
              f'remote cloud dataset ID: {cloud_dataset_id}...')

    if sync_options.dry_run:
        print(f'[DryRun] Would delete remote documents with API IDs from cloud '
              f'dataset {cloud_dataset_id}:')
        for api_id in remote_api_ids_to_delete:
            print(f'  {api_id}')
    else:
        success, _ = bulk_delete_documents(cloud_dataset_id, remote_api_ids_to_delete)
        if not success:
            print('Warning: Failed to bulk delete documents')
        if sync_options.verbose:
            print('Deleted documents.')
