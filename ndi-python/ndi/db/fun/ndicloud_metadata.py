"""
NDI Database Function - Prepare metadata for NDI Cloud.

Prepare document and file metadata for upload to NDI Cloud.
Simplified version for Phase 2 implementation.
"""

from typing import Dict, List, Any, Optional


def ndicloud_metadata(session_or_dataset: Any,
                      include_files: bool = True) -> Dict[str, Any]:
    """
    Prepare metadata for NDI Cloud upload.

    Collects and organizes document metadata and file information
    from a session or dataset in a format suitable for cloud upload.

    Args:
        session_or_dataset: ndi.session or ndi.dataset object
        include_files: If True, include file metadata (default: True)

    Returns:
        Dictionary containing:
        - 'documents': List of document metadata dictionaries
        - 'files': List of file metadata dictionaries (if include_files=True)
        - 'session_info': Session metadata
        - 'stats': Statistics about the metadata

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> metadata = ndicloud_metadata(session)
        >>> print(f"Found {len(metadata['documents'])} documents")

    Notes:
        - This is a simplified implementation for Phase 2
        - Full cloud integration will be added in Phase 5
        - Metadata includes document properties but not binary data
        - File metadata includes paths and sizes but not content

    Raises:
        TypeError: If session_or_dataset is not valid
    """
    from ...query import Query

    # Validate input
    if not hasattr(session_or_dataset, 'database_search'):
        raise TypeError('Input must be an ndi.session or ndi.dataset object')

    metadata = {
        'documents': [],
        'files': [],
        'session_info': {},
        'stats': {
            'document_count': 0,
            'file_count': 0,
            'total_file_size': 0
        }
    }

    # Get session information
    if hasattr(session_or_dataset, 'id'):
        metadata['session_info']['session_id'] = session_or_dataset.id()
    if hasattr(session_or_dataset, 'reference'):
        metadata['session_info']['reference'] = session_or_dataset.reference

    # Search for all documents
    q_all = Query('', 'isa', 'base', '')
    docs = session_or_dataset.database_search(q_all)

    # Process each document
    for doc in docs:
        # Add document metadata
        doc_meta = {
            'id': doc.id(),
            'type': doc.document_properties.get('document_class', {}).get('class_name', 'document'),
            'datestamp': doc.document_properties.get('base', {}).get('datestamp', ''),
            'has_files': 'files' in doc.document_properties
        }
        metadata['documents'].append(doc_meta)
        metadata['stats']['document_count'] += 1

        # Process files if requested
        if include_files and 'files' in doc.document_properties:
            file_info_list = doc.document_properties['files'].get('file_info', [])

            for file_info in file_info_list:
                filename = file_info.get('name', '')
                locations = file_info.get('locations', [])

                for location in locations:
                    file_path = location.get('location', '')
                    if file_path:
                        import os
                        file_size = os.path.getsize(file_path) if os.path.exists(file_path) else 0

                        file_meta = {
                            'document_id': doc.id(),
                            'filename': filename,
                            'path': file_path,
                            'size': file_size
                        }
                        metadata['files'].append(file_meta)
                        metadata['stats']['file_count'] += 1
                        metadata['stats']['total_file_size'] += file_size

    return metadata
