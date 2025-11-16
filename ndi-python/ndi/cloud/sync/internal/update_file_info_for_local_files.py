"""Update file info of document for local files.

Ported from: ndi.cloud.sync.internal.updateFileInfoForLocalFiles (MATLAB)
"""

import os
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.document import Document


def update_file_info_for_local_files(document: 'Document', file_directory: str) -> 'Document':
    """Update file info of document for local files.

    Updates the file info of the document to point to a file in the provided
    (local) file directory.

    Args:
        document: The document object that contains file info to be updated
        file_directory: The directory where local files are stored

    Returns:
        The updated document object with new file info
    """
    if document.has_files():
        original_file_info = document.document_properties.get('files', {}).get('file_info', [])
        document = document.reset_file_info()

        for info in original_file_info:
            locations = info.get('locations', [])
            if locations:
                file_uid = locations[0].get('uid')
                if file_uid:
                    file_location = os.path.join(file_directory, file_uid)

                    filename = info.get('name')  # name for ingestion
                    if os.path.isfile(file_location):
                        document = document.add_file(filename, file_location)
                    else:
                        print(f'Warning: Local file does not exist for document '
                              f'"{document.document_properties["base"]["id"]}"')

    return document
