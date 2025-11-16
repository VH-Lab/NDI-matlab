"""
NDI Database Function - Find all dependencies.

Find documents that have dependencies on provided documents (recursive forward search).
"""

from typing import List, Set, Any, Optional


def findalldependencies(session_or_dataset: Any,
                        visited: Optional[Set[str]] = None,
                        *docs) -> List[Any]:
    """
    Find all documents that depend on the provided documents.

    Searches the database and returns all documents that have a
    dependency ('depends_on') field for which the 'value' field
    corresponds to the id of the provided documents.

    This performs a recursive forward search through the dependency graph.

    Args:
        session_or_dataset: ndi.session or ndi.dataset object
        visited: Set of document IDs already visited (for recursion tracking).
                 Provide None or empty set on first call.
        *docs: One or more ndi.document objects to find dependencies for

    Returns:
        List of ndi.document objects that depend on the provided documents

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> # Find all documents that depend on doc1
        >>> dependencies = findalldependencies(session, None, doc1)
        >>> # Find all documents that depend on doc1 or doc2
        >>> dependencies = findalldependencies(session, None, doc1, doc2)

    Notes:
        - Performs recursive depth-first search
        - Tracks visited documents to avoid infinite loops
        - Returns empty list if no dependencies found
        - Dependencies are documents that reference the provided docs
        - Use findallantecedents() to search backwards (what docs depend on)

    See also:
        findallantecedents - Find documents that the provided documents depend on
    """
    from ...query import Query

    # Validate input type
    if not hasattr(session_or_dataset, 'database_search'):
        raise TypeError('Input must be an ndi.session or ndi.dataset object')

    d = []

    if visited is None:
        visited = set()

    # Mark all input documents as visited
    for doc in docs:
        visited.add(doc.id())

    # For each input document, find what depends on it
    for doc in docs:
        # Query for documents that depend on this document
        q_v = Query('', 'depends_on', '*', doc.id())
        bb = session_or_dataset.database_search(q_v)

        for found_doc in bb:
            id_here = found_doc.id()

            # Only process if we haven't seen this document
            if id_here not in visited:
                visited.add(id_here)
                d.append(found_doc)

                # Recursively find dependencies of this document
                newdocs = findalldependencies(session_or_dataset, visited, found_doc)

                if newdocs:
                    # Add new document IDs to visited set
                    for new_doc in newdocs:
                        visited.add(new_doc.id())
                    d.extend(newdocs)

    return d
