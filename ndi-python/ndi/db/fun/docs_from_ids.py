"""
NDI Database Function - Retrieve documents from IDs.

Retrieve multiple ndi.document objects given an array of IDs in a single query.
This is faster than searching for each document one at a time.
"""

from typing import List, Optional, Any, Union


def docs_from_ids(session_or_dataset: Any,
                  document_ids: List[str]) -> List[Optional[Any]]:
    """
    Read ndi.document objects given an array of IDs in a single query.

    Retrieve a set of documents that correspond to a list of document IDs.
    This function is faster than similar code that searches for each document
    one at a time because it combines the search into a single query.

    Args:
        session_or_dataset: ndi.session or ndi.dataset object
        document_ids: List of document ID strings

    Returns:
        List the same size as document_ids. If the document is found, it
        is provided at that index. Otherwise, the entry is None.

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> ids = ['abc123...', 'def456...', 'ghi789...']
        >>> docs = docs_from_ids(session, ids)
        >>> # docs[0] is the document with id 'abc123...' or None if not found

    Notes:
        - Uses OR queries to combine all searches into one database call
        - Much faster than individual searches for large ID lists
        - Maintains order: docs[i] corresponds to document_ids[i]
    """
    if not document_ids:
        return []

    from ...query import Query

    # Build OR query for all document IDs
    q = None

    for doc_id in document_ids:
        q_here = Query('base.id', 'exact_string', doc_id, '')
        if q is None:
            q = q_here
        else:
            q = q | q_here

    # Search database with combined query
    docs_here = session_or_dataset.database_search(q)

    # Create result list in same order as input IDs
    docs = [None] * len(document_ids)

    for i, doc_id in enumerate(document_ids):
        for doc in docs_here:
            if doc.document_properties.base.id == doc_id:
                docs[i] = doc
                break  # Found it, stop searching

    return docs
