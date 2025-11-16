"""
Document manipulation utilities for NDI.

Provides helper functions for working with NDI documents.
"""

from typing import List, Dict, Any, Optional


def merge_documents(docs: List) -> Optional[Any]:
    """
    Merge multiple documents into one.

    Args:
        docs: List of documents to merge

    Returns:
        Merged document or None if list is empty
    """
    if not docs:
        return None

    if len(docs) == 1:
        return docs[0]

    # Merge logic - combine properties
    base_doc = docs[0]
    for doc in docs[1:]:
        # Merge properties (implementation depends on Document class structure)
        pass

    return base_doc


def filter_documents_by_type(docs: List, doc_type: str) -> List:
    """
    Filter documents by type.

    Args:
        docs: List of documents
        doc_type: Document type to filter for

    Returns:
        Filtered list of documents
    """
    filtered = []
    for doc in docs:
        if hasattr(doc, 'document_properties'):
            props = doc.document_properties
            if props.get('document_class', {}).get('class_name') == doc_type:
                filtered.append(doc)
    return filtered


def sort_documents_by_timestamp(docs: List, reverse: bool = False) -> List:
    """
    Sort documents by timestamp.

    Args:
        docs: List of documents
        reverse: If True, sort in descending order

    Returns:
        Sorted list of documents
    """
    def get_timestamp(doc):
        if hasattr(doc, 'document_properties'):
            return doc.document_properties.get('base', {}).get('datestamp', '')
        return ''

    return sorted(docs, key=get_timestamp, reverse=reverse)
