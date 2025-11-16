"""
Find ingested documents from an NDI session.

This module provides functionality to locate all documents that correspond
to ingested data in an NDI session.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/find_ingested_docs.m
"""

from typing import List


def find_ingested_docs(session) -> List:
    """
    Find all ingested documents from an ndi.session.

    Returns all documents in the ndi.session that correspond to ingested data.
    These are documents that represent data that has been imported/ingested
    into the NDI system from DAQ systems or other sources.

    Args:
        session: An ndi.session object

    Returns:
        List of ndi.document objects that are ingested data documents

    Example:
        >>> from ndi.session import Session
        >>> session = Session('/path/to/session')
        >>> ingested = find_ingested_docs(session)
        >>> print(f"Found {len(ingested)} ingested documents")

    Notes:
        - Searches for three types of ingested documents:
          1. daqreader_mfdaq_epochdata_ingested - Multi-function DAQ ingested data
          2. daqmetadatareader_epochdata_ingested - DAQ metadata ingested data
          3. epochfiles_ingested - Epoch files ingested data
        - Uses OR logic to combine the three queries
        - Returns empty list if no ingested documents found
    """
    from ndi.query import Query

    # Query for different types of ingested documents
    q_i1 = Query('', 'isa', 'daqreader_mfdaq_epochdata_ingested', '')
    q_i2 = Query('', 'isa', 'daqmetadatareader_epochdata_ingested', '')
    q_i3 = Query('', 'isa', 'epochfiles_ingested', '')

    # Combine queries with OR logic
    combined_query = q_i1 | q_i2 | q_i3

    # Execute search
    docs = session.database_search(combined_query)

    # Ensure we return a list
    if docs is None:
        return []
    elif not isinstance(docs, list):
        return [docs]
    else:
        return docs
