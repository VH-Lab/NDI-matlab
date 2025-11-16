"""Identify files that have not yet been uploaded to a cloud dataset.

Ported from: ndi.cloud.sync.internal.filesNotYetUploaded (MATLAB)
"""

from typing import List, Dict, Any, Tuple


def files_not_yet_uploaded(
    file_manifest: List[Dict[str, Any]],
    cloud_dataset_id: str
) -> Tuple[List[Dict[str, Any]], str]:
    """Identify files that have not yet been uploaded to a cloud dataset.

    Given a file manifest (a list of dicts with keys 'uid', 'bytes', 'file_path',
    'is_uploaded'), and a cloud dataset ID, this function returns a new list
    containing only those files that need to be uploaded.

    A file is considered to need uploading if it is not present in the remote
    dataset's file list, or if it is present but its 'uploaded' status is false.

    Args:
        file_manifest: A list of file dictionaries with fields:
            - uid: File UID
            - bytes: File size in bytes
            - file_path: Path to the file
            - is_uploaded: Whether the file has been uploaded
        cloud_dataset_id: The unique identifier of the cloud dataset

    Returns:
        A tuple containing:
            - files_to_upload: A list of file dictionaries to be uploaded
            - message: An error message if the operation fails, empty string otherwise
    """
    from ndi.cloud.api.files import list_files

    files_to_upload = []
    message = ''

    success, file_list = list_files(cloud_dataset_id, check_for_updates=True)

    if success:
        # Create a map of remote files for quick lookup
        remote_files = {file_info['uid']: file_info for file_info in file_list}

        for file_item in file_manifest:
            file_uid = file_item['uid']

            # Check if file needs to be uploaded
            if (file_uid not in remote_files or
                (file_uid in remote_files and
                 'uploaded' in remote_files[file_uid] and
                 not remote_files[file_uid]['uploaded'])):

                new_struct = {
                    'uid': file_item['uid'],
                    'bytes': file_item['bytes'],
                    'file_path': file_item['file_path'],
                    'is_uploaded': file_item['is_uploaded']
                }
                files_to_upload.append(new_struct)
    else:
        message = 'Could not retrieve remote dataset file list.'

    return files_to_upload, message
