"""Update file info of document for remote (cloud-only) files.

Ported from: ndi.cloud.sync.internal.updateFileInfoForRemoteFiles (MATLAB)
"""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ndi.document import Document


def update_file_info_for_remote_files(document: 'Document', cloud_dataset_id: str) -> 'Document':
    """Update file info of document for remote (cloud-only) files.

    This function updates the file information in the provided document
    object for files that are stored remotely in NDI cloud.

    The following changes are made to the file location structure:
        1. set the 'delete_original' and 'ingest' fields to false.
        2. set the location field using the template "ndic://{dataset_id}/{file_uid}"
        3. set the location_type field to "ndicloud"

    Args:
        document: The document object containing file information
        cloud_dataset_id: The unique identifier for the cloud dataset

    Returns:
        The updated document object with modified file info
    """
    if document.has_files():
        updated_file_info = document.document_properties.get('files', {}).get('file_info', [])

        for info in updated_file_info:
            locations = info.get('locations', [])
            if locations:
                # Replace/override 1st file location
                locations[0]['delete_original'] = False
                locations[0]['ingest'] = False

                file_uid = locations[0].get('uid')
                if file_uid:
                    file_location = f'ndic://{cloud_dataset_id}/{file_uid}'
                    locations[0]['location'] = file_location
                    locations[0]['location_type'] = 'ndicloud'

        document = document.setproperties('files.file_info', updated_file_info)

    return document
