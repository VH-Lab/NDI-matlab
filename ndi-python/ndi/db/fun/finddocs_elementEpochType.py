"""
Search for documents in the NDI database by element, epoch, and type.

This module provides functionality to construct and execute database queries
based on element ID, epoch ID, and document type.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/finddocs_elementEpochType.m
"""

from typing import List, Union


def finddocs_elementEpochType(
    session,
    element_id: str,
    epoch_id: str,
    document_type: str
) -> List:
    """
    Search for documents in the NDI database by element, epoch, and type.

    This function constructs database queries using ndi.query based on the
    provided session object, element ID, epoch ID, and document type. It then
    combines these queries and executes a search to retrieve matching documents.

    Args:
        session: An ndi.session or ndi.dataset object
        element_id: The ndi.element ID (string)
        epoch_id: The ndi.element epoch_id (string)
        document_type: The type of document to search for (e.g., 'spectrogram')

    Returns:
        List of documents matching the search criteria

    Raises:
        TypeError: If session is not an ndi.session or ndi.dataset object
        ValueError: If element_id, epoch_id, or document_type are empty

    Example:
        >>> from ndi.session import Session
        >>> session = Session('/path/to/session')
        >>> element_id = '1234567890abcdef'
        >>> epoch_id = 'epoch_001'
        >>> docs = finddocs_elementEpochType(session, element_id, epoch_id, 'spectrogram')
        >>> print(f"Found {len(docs)} documents")

    Notes:
        - Combines three query conditions with AND logic:
          1. Document is of specified type (ISA query)
          2. Document depends on specified element_id
          3. Document has specified epoch_id
        - Returns empty list if no documents match all criteria
    """
    from ndi.query import Query

    # Validate inputs
    if not element_id or not isinstance(element_id, str):
        raise ValueError("element_id must be a non-empty string")

    if not epoch_id or not isinstance(epoch_id, str):
        raise ValueError("epoch_id must be a non-empty string")

    if not document_type or not isinstance(document_type, str):
        raise ValueError("document_type must be a non-empty string")

    # Construct queries
    # Q1: Document is of the specified type
    q1 = Query('', 'isa', document_type, '')

    # Q2: Document depends on the specified element
    q2 = Query('', 'depends_on', 'element_id', element_id)

    # Q3: Document has the specified epoch_id
    q3 = Query('epochid.epochid', 'exact_string', epoch_id, '')

    # Combine queries with AND logic
    combined_query = q1 & q2 & q3

    # Execute search
    docs = session.database_search(combined_query)

    # Ensure we return a list
    if docs is None:
        return []
    elif not isinstance(docs, list):
        return [docs]
    else:
        return docs
