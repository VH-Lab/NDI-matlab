"""
Find documents with missing dependencies.

This module provides functionality to search for documents that have
dependencies on documents that do not exist in the database.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/finddocs_missing_dependencies.m
"""

from typing import List, Optional


def finddocs_missing_dependencies(session, *dependency_names) -> List:
    """
    Find documents that have dependencies on documents that do not exist.

    Searches the database of the session and returns all documents that have a
    dependency ('depends_on') field for which the 'value' field does not
    correspond to an existing document.

    Args:
        session: An ndi.session or ndi.dataset object
        *dependency_names: Optional variable-length list of dependency field names
            to check. If provided, only examines variables with depends_on fields
            with these names. If not provided, checks all depends_on fields.

    Returns:
        List of ndi.document objects that have missing dependencies

    Example:
        >>> from ndi.session import Session
        >>> session = Session('/path/to/session')
        >>> # Find all documents with any missing dependencies
        >>> docs = finddocs_missing_dependencies(session)
        >>> # Find documents with missing 'element_id' or 'stimulus_id' dependencies
        >>> docs = finddocs_missing_dependencies(session, 'element_id', 'stimulus_id')

    Notes:
        - Maintains a cache of observed documents to avoid redundant searches
        - Only returns documents with at least one missing dependency
        - Stops checking a document after finding the first missing dependency
    """
    from ndi.query import Query

    # Keep track of what we have seen so we don't have to search multiple times
    documents_observed = {}

    # Find all documents that have any depends_on field
    q = Query('depends_on', 'hasfield', '', '')
    docs = session.database_search(q)

    # Ensure docs is a list
    if not isinstance(docs, list):
        docs = [docs] if docs is not None else []

    # Track all document IDs we've already seen
    for doc in docs:
        documents_observed[doc.id()] = True

    include_indices = []

    # Check each document for missing dependencies
    for i, doc in enumerate(docs):
        # Get the depends_on field
        depends_on = doc.document_properties.get('depends_on', [])

        # Handle both list and dict formats
        if isinstance(depends_on, dict):
            # Convert dict to list format for easier processing
            depends_on_list = []
            for key, value in depends_on.items():
                if key.endswith(tuple(str(n) for n in range(10))):  # numbered dependencies
                    # Extract the base name (e.g., 'element_id' from 'element_id_1')
                    parts = key.rsplit('_', 1)
                    if len(parts) == 2 and parts[1].isdigit():
                        name = parts[0]
                    else:
                        name = key
                else:
                    name = key
                depends_on_list.append({'name': name, 'value': value})
            depends_on = depends_on_list
        elif not isinstance(depends_on, list):
            # Skip if depends_on is not in expected format
            continue

        # Check each dependency
        for dependency in depends_on:
            # Get dependency name and value
            if isinstance(dependency, dict):
                dep_name = dependency.get('name', '')
                dep_value = dependency.get('value', '')
            else:
                # Skip if dependency is not a dict
                continue

            # If specific dependency names were provided, check if this one matches
            if dependency_names:
                match = dep_name in dependency_names
            else:
                match = True

            if match and dep_value:
                # Check if we've already seen this document
                if dep_value in documents_observed:
                    # We've got it already
                    continue
                else:
                    # We need to look for it in the database
                    q_here = Query('base.id', 'exact_string', dep_value, '')
                    docs_here = session.database_search(q_here)

                    if docs_here:
                        # Document exists, add to observed
                        if not isinstance(docs_here, list):
                            docs_here = [docs_here]
                        if docs_here:
                            documents_observed[docs_here[0].id()] = True
                    else:
                        # No match - this is a missing dependency
                        include_indices.append(i)
                        break  # Move on to next document, skip rest of dependencies

    # Return only documents with missing dependencies
    return [docs[i] for i in include_indices]
