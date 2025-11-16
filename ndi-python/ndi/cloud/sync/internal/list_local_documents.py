"""List documents in local dataset.

Ported from: ndi.cloud.sync.internal.listLocalDocuments (MATLAB)
"""

from typing import Tuple, List, TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.dataset import Dataset
    from ndi.document import Document


def list_local_documents(ndi_dataset: 'Dataset') -> Tuple[List['Document'], List[str]]:
    """List documents in local dataset.

    Utility function to retrieve all documents from a local dataset and
    optionally also return their document ids.

    Args:
        ndi_dataset: The local NDI dataset object

    Returns:
        A tuple containing:
            - documents: List of document objects
            - document_ids: List of document ID strings
    """
    from ndi.query import Query

    # Search for all documents using base query
    query = Query('', 'isa', 'base')
    documents = ndi_dataset.database_search(query)

    # Extract document IDs
    document_ids = [
        doc.document_properties['base']['id']
        for doc in documents
    ]

    return documents, document_ids
