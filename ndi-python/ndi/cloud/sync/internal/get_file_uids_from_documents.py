"""Extract all unique file UIDs from a list of NDI documents.

Ported from: ndi.cloud.sync.internal.getFileUidsFromDocuments (MATLAB)
"""

from typing import List, TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.document import Document


def get_file_uids_from_documents(ndi_documents: List['Document']) -> List[str]:
    """Extract all unique file UIDs from a list of NDI documents.

    This function iterates through each document, and if the document has files,
    it extracts the UIDs from the file_info.locations.

    Args:
        ndi_documents: A list of ndi.document objects

    Returns:
        A list of unique file UIDs found in the documents. Returns an empty
        list if no files are found or if ndi_documents is empty.
    """
    file_uids_list = []

    if not ndi_documents:
        return []

    for document in ndi_documents:
        if hasattr(document, 'has_files') and document.has_files():
            file_info = document.document_properties.get('files', {}).get('file_info', [])

            for info in file_info:
                # Each file_info can have multiple locations, each with a UID
                locations = info.get('locations', [])
                if locations:
                    for location in locations:
                        uid = location.get('uid')
                        if uid:
                            file_uids_list.append(uid)

    if file_uids_list:
        # Return unique UIDs while preserving order
        seen = set()
        unique_uids = []
        for uid in file_uids_list:
            if uid not in seen:
                seen.add(uid)
                unique_uids.append(uid)
        return unique_uids
    else:
        return []
