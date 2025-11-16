"""
NDI Database Function - Find all antecedents.

Find documents that the provided documents depend on (recursive backward search).
"""

from typing import List, Set, Any, Optional


def findallantecedents(session_or_dataset: Any,
                       visited: Optional[Set[str]] = None,
                       *docs) -> List[Any]:
    """
    Find all documents that the provided documents depend on.

    Searches the database and returns all documents for which the provided
    documents have a dependency. This function crawls up the list of
    'depends_on' fields to find all documents that the provided documents
    depend on.

    This performs a recursive backward search through the dependency graph.

    Args:
        session_or_dataset: ndi.session or ndi.dataset object
        visited: Set of document IDs already visited (for recursion tracking).
                 Provide None or empty set on first call.
        *docs: One or more ndi.document objects to find antecedents for

    Returns:
        List of ndi.document objects that the provided documents depend on

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> # Find all documents that doc1 depends on
        >>> antecedents = findallantecedents(session, None, doc1)
        >>> # Find all documents that doc1 or doc2 depend on
        >>> antecedents = findallantecedents(session, None, doc1, doc2)

    Notes:
        - Performs recursive depth-first search
        - Tracks visited documents to avoid infinite loops
        - Returns empty list if no dependencies found
        - Antecedents are documents that the provided docs reference
        - Use findalldependencies() to search forwards (what depends on docs)

    See also:
        findalldependencies - Find documents that depend on the provided documents
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

    # For each input document, find what it depends on
    for doc in docs:
        # Get dependencies from this document
        dep_names, dep_structs = doc.dependency()

        if not dep_structs:
            continue  # No dependencies

        # Build query for all dependency IDs
        ids = [dep['value'] for dep in dep_structs]

        if len(ids) > 0:
            # Build OR query for all dependency IDs
            q_v = Query('base.id', 'exact_string', ids[0], '')
            for dep_id in ids[1:]:
                q_v = q_v | Query('base.id', 'exact_string', dep_id, '')

            # Search for dependency documents
            bb = session_or_dataset.database_search(q_v)

            for found_doc in bb:
                id_here = found_doc.id()

                # Only process if we haven't seen this document
                if id_here not in visited:
                    visited.add(id_here)
                    d.append(found_doc)

                    # Recursively find antecedents of this document
                    newdocs = findallantecedents(session_or_dataset, visited, found_doc)

                    if newdocs:
                        # Add new document IDs to visited set
                        for new_doc in newdocs:
                            visited.add(new_doc.id())
                        d.extend(newdocs)

    return d
