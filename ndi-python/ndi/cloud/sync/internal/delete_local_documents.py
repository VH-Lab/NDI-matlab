"""Delete specified documents from the local NDI dataset.

Ported from: ndi.cloud.sync.internal.deleteLocalDocuments (MATLAB)
"""

from typing import List, TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.dataset import Dataset
    from ndi.cloud.sync.sync_options import SyncOptions


def delete_local_documents(
    ndi_dataset: 'Dataset',
    local_ids_to_delete: List[str],
    sync_options: 'SyncOptions'
) -> None:
    """Delete specified documents from the local NDI dataset.

    This function iterates through the provided document IDs, searches for them
    in the local dataset, and removes them if found. It respects the
    dry_run option in sync_options.

    Args:
        ndi_dataset: The local NDI dataset object
        local_ids_to_delete: A list of NDI document UUIDs to delete from
            the local dataset
        sync_options: Synchronization options, primarily for dry_run and
            verbose flags
    """
    from ndi.query import Query

    if not local_ids_to_delete:
        if sync_options.verbose:
            print('No local document IDs provided for deletion.')
        return

    if sync_options.verbose:
        print(f'Attempting to delete {len(local_ids_to_delete)} documents from '
              f'local dataset: {ndi_dataset.path}...')

    num_deleted = 0
    num_not_found = 0

    for doc_id in local_ids_to_delete:
        if sync_options.dry_run:
            # In DryRun, we can't confirm if the doc exists without searching,
            # but the intent is to log what *would* be deleted.
            # A search could be done even in DryRun for more accurate logging.
            query = Query('base.id', 'exact_string', doc_id, '')
            docs = ndi_dataset.database_search(query)
            if docs:
                print(f'[DryRun] Would delete local document with ID: {doc_id}')
                num_deleted += 1  # Count as if it would be deleted
            else:
                print(f'[DryRun] Local document with ID: {doc_id} not found, '
                      f'would not delete.')
                num_not_found += 1
        else:
            query = Query('base.id', 'exact_string', doc_id, '')
            docs = ndi_dataset.database_search(query)

            if docs:
                try:
                    ndi_dataset.database_rm(doc_id)
                    if sync_options.verbose:
                        print(f'Deleted local document with ID: {doc_id}')
                    num_deleted += 1
                except Exception as e:
                    print(f'Error deleting local document ID {doc_id}: {str(e)}')
            else:
                if sync_options.verbose:
                    print(f'Local document with ID: {doc_id} not found for deletion.')
                num_not_found += 1

    if sync_options.verbose:
        if sync_options.dry_run:
            print(f'[DryRun] Summary: Would have attempted to delete '
                  f'{len(local_ids_to_delete)} documents. {num_deleted} would be '
                  f'deleted, {num_not_found} not found.')
        else:
            print(f'Deletion summary: Attempted to delete {len(local_ids_to_delete)} '
                  f'documents. {num_deleted} deleted, {num_not_found} not found.')
