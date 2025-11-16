"""
NDI Document Utilities - Functions for working with NDI documents.

This module provides utility functions for searching, manipulating, and
analyzing NDI documents.
"""

from typing import Any, Optional, Tuple


def find_fuid(ndi_obj: Any, fuid: str) -> Tuple[Optional[Any], Optional[str]]:
    """
    Find a document by file UID (fuid).

    Searches all documents in an NDI dataset or session for a document
    with a matching file UID. Returns the first match found.

    This is the Python equivalent of MATLAB's ndi.fun.doc.findFuid function.

    Args:
        ndi_obj: NDI session or dataset object to search in
        fuid: File UID string to search for

    Returns:
        Tuple of (document, filename):
        - document: The first matching NDI document, or None if not found
        - filename: The filename where the document was found, or None if not found

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> doc, filename = find_fuid(session, 'a1b2c3d4e5f6g7h8_i9j0k1l2m3n4o5p6q')
        >>> if doc is not None:
        ...     print(f'Found document in {filename}')

    Notes:
        - Searches through all documents in the session/dataset
        - Returns immediately upon finding first match (does not continue searching)
        - Returns (None, None) if no matching document is found
        - File UID is checked against the document.dependency.value field
    """
    # Check if ndi_obj has the required methods
    if not hasattr(ndi_obj, 'database_search'):
        raise TypeError('ndi_obj must be an NDI session or dataset object with database_search method')

    # Search for all documents (we'll filter for fuid)
    # We need to search through documents and check their dependencies
    try:
        # Get all documents - exact method may vary depending on implementation
        # In NDI, we typically search with an empty query to get all docs
        search_results = ndi_obj.database_search({})

        # Iterate through results
        for doc in search_results:
            # Check if document has dependencies
            if hasattr(doc, 'dependency') and doc.dependency is not None:
                # Dependencies can be a single dependency or a list
                dependencies = doc.dependency if isinstance(doc.dependency, list) else [doc.dependency]

                # Check each dependency
                for dep in dependencies:
                    if hasattr(dep, 'value') and dep.value == fuid:
                        # Found matching fuid - get filename
                        # The filename is typically stored in the document or can be derived
                        filename = getattr(doc, 'file_id', None)
                        if filename is None and hasattr(doc, 'document_properties'):
                            filename = getattr(doc.document_properties, 'file_id', None)

                        return doc, filename

    except Exception as e:
        # If search fails, we might need a different approach
        # Try alternative method if available
        if hasattr(ndi_obj, 'documents'):
            # Some implementations may have a documents property
            docs = ndi_obj.documents()

            for doc in docs:
                if hasattr(doc, 'dependency') and doc.dependency is not None:
                    dependencies = doc.dependency if isinstance(doc.dependency, list) else [doc.dependency]

                    for dep in dependencies:
                        if hasattr(dep, 'value') and dep.value == fuid:
                            filename = getattr(doc, 'file_id', None)
                            if filename is None and hasattr(doc, 'document_properties'):
                                filename = getattr(doc.document_properties, 'file_id', None)

                            return doc, filename

    # No matching document found
    return None, None


def find_document_by_id(ndi_obj: Any, doc_id: str) -> Optional[Any]:
    """
    Find a document by its document ID.

    Searches for a document with the specified NDI document ID.

    Args:
        ndi_obj: NDI session or dataset object to search in
        doc_id: Document ID string to search for

    Returns:
        The matching NDI document, or None if not found

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> doc = find_document_by_id(session, 'a1b2c3d4e5f6g7h8_i9j0k1l2m3n4o5p6q')
        >>> if doc is not None:
        ...     print('Found document')

    Notes:
        - Document ID is the unique identifier for NDI documents
        - Returns None if no matching document is found
    """
    # Check if ndi_obj has the required methods
    if not hasattr(ndi_obj, 'database_search'):
        raise TypeError('ndi_obj must be an NDI session or dataset object')

    # Search by document ID
    try:
        search_query = {'document_properties.document_class.document_id': doc_id}
        results = ndi_obj.database_search(search_query)

        if results and len(results) > 0:
            return results[0]

    except Exception:
        # Try alternative approach
        if hasattr(ndi_obj, 'documents'):
            docs = ndi_obj.documents()

            for doc in docs:
                if hasattr(doc, 'id') and doc.id() == doc_id:
                    return doc

                # Check document_properties
                if hasattr(doc, 'document_properties'):
                    if hasattr(doc.document_properties, 'document_class'):
                        if hasattr(doc.document_properties.document_class, 'document_id'):
                            if doc.document_properties.document_class.document_id == doc_id:
                                return doc

    return None


def get_document_dependencies(doc: Any) -> list:
    """
    Extract all dependencies from a document.

    Args:
        doc: NDI document object

    Returns:
        List of dependency objects (may be empty)

    Examples:
        >>> deps = get_document_dependencies(my_document)
        >>> for dep in deps:
        ...     print(f'Dependency value: {dep.value}')

    Notes:
        - Returns empty list if document has no dependencies
        - Handles both single dependency and list of dependencies
    """
    if not hasattr(doc, 'dependency') or doc.dependency is None:
        return []

    # Handle single dependency or list
    if isinstance(doc.dependency, list):
        return doc.dependency
    else:
        return [doc.dependency]


def has_dependency_value(doc: Any, value: str) -> bool:
    """
    Check if a document has a dependency with the specified value.

    Args:
        doc: NDI document object
        value: Dependency value to search for (typically a file UID)

    Returns:
        True if document has a dependency with this value, False otherwise

    Examples:
        >>> if has_dependency_value(my_doc, 'some_fuid_value'):
        ...     print('Document depends on this file')

    Notes:
        - Case-sensitive comparison
        - Checks all dependencies if multiple exist
    """
    dependencies = get_document_dependencies(doc)

    for dep in dependencies:
        if hasattr(dep, 'value') and dep.value == value:
            return True

    return False
