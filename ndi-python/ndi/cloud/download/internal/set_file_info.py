"""
Set file information for downloaded documents.

Ported from MATLAB: ndi.cloud.download.internal.setFileInfo
"""

from typing import List, Dict, Any
from ndi.document import Document


def set_file_info(documents: List[Document], file_info: Dict[str, Any]) -> List[Document]:
    """
    Update file information in documents with actual local paths.

    Args:
        documents: List of Document objects
        file_info: Dictionary mapping file UIDs to local paths

    Returns:
        List of updated Document objects

    Example:
        >>> file_info = {'file_uid_1': '/path/to/file1', 'file_uid_2': '/path/to/file2'}
        >>> updated_docs = set_file_info(documents, file_info)
    """
    for doc in documents:
        if 'files' in doc.document_properties:
            files_list = doc.document_properties.get('files', [])

            for file_entry in files_list:
                if isinstance(file_entry, dict):
                    file_uid = file_entry.get('uid') or file_entry.get('file_uid')

                    if file_uid and file_uid in file_info:
                        # Update the file path to point to downloaded location
                        file_entry['local_path'] = file_info[file_uid]

    return documents
