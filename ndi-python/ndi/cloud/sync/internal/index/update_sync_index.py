"""Update synchronization index for the dataset.

Ported from: ndi.cloud.sync.internal.index.updateSyncIndex (MATLAB)
"""

from typing import Optional, List, TYPE_CHECKING

from ndi.cloud.sync.internal.index.create_sync_index_struct import create_sync_index_struct
from ndi.cloud.sync.internal.index.write_sync_index import write_sync_index

if TYPE_CHECKING:
    from ndi.dataset import Dataset


def update_sync_index(
    ndi_dataset: 'Dataset',
    cloud_dataset_id: str,
    local_document_ids: Optional[List[str]] = None,
    remote_document_ids: Optional[List[str]] = None
) -> None:
    """Update synchronization index for the dataset.

    Updates the synchronization index for the specified dataset using the provided
    index data.

    Args:
        ndi_dataset: The dataset to be updated
        cloud_dataset_id: The identifier for the cloud dataset
        local_document_ids: Local document IDs (optional). If not provided,
            will be fetched from the dataset
        remote_document_ids: Remote document IDs (optional). If not provided,
            will be fetched from the remote dataset
    """
    # Import here to avoid circular imports
    from ndi.cloud.sync.internal.list_local_documents import list_local_documents
    from ndi.cloud.sync.internal.list_remote_document_ids import list_remote_document_ids

    if local_document_ids is None:
        _, local_document_ids = list_local_documents(ndi_dataset)

    if remote_document_ids is None:
        remote_doc_id_map = list_remote_document_ids(cloud_dataset_id)
        remote_document_ids = remote_doc_id_map['ndi_id']

    sync_index = create_sync_index_struct(local_document_ids, remote_document_ids)

    write_sync_index(ndi_dataset, sync_index)
