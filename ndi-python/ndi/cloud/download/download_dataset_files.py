"""
Download dataset files from NDI Cloud.

Ported from MATLAB: ndi.cloud.download.downloadDatasetFiles
"""

from typing import Dict, List, Optional
import os
import urllib.request
import warnings
from ..api import datasets, files as files_api


def download_dataset_files(
    cloud_dataset_id: str,
    target_folder: str,
    file_uuids: Optional[List[str]] = None,
    verbose: bool = True,
    abort_on_error: bool = True
) -> None:
    """
    Download dataset files from a cloud dataset.

    Downloads specified files or all files from a cloud dataset to the target
    folder. Files are saved with their UID as the filename.

    Args:
        cloud_dataset_id: The identifier of the cloud dataset
        target_folder: The folder where files will be downloaded.
                      Must be a valid folder path.
        file_uuids: (Optional) The unique identifiers of the files to download.
                   If None or empty, all files will be downloaded.
        verbose: Flag to enable verbose output (default: True)
        abort_on_error: Flag to control whether to abort on download errors
                       (default: True)

    Returns:
        None

    Raises:
        RuntimeError: If dataset retrieval fails
        RuntimeError: If requested files are not found in dataset
        Exception: If abort_on_error is True and download fails

    Example:
        >>> # Download all files from a dataset
        >>> download_dataset_files('dataset123', '/path/to/output')
        >>>
        >>> # Download specific files
        >>> file_ids = ['file_abc', 'file_def']
        >>> download_dataset_files('dataset456', '/path/to/output', file_ids)

    Notes:
        - Skips files that already exist locally
        - Skips files that haven't been uploaded to cloud yet
        - Files are saved with their UID as the filename
        - Progress is shown if verbose=True

    Ported from MATLAB: ndi.cloud.download.downloadDatasetFiles
    Source: /home/user/NDI-matlab/src/ndi/+ndi/+cloud/+download/downloadDatasetFiles.m
    """
    # Validate target folder exists
    if not os.path.isdir(target_folder):
        raise ValueError(f'Target folder does not exist or is not a directory: {target_folder}')

    # Get authentication token from environment
    token = os.getenv('NDI_CLOUD_TOKEN')
    if not token:
        raise RuntimeError('No authentication token found. Please set NDI_CLOUD_TOKEN environment variable.')

    # Get dataset info
    success, dataset_info, _, _ = datasets.get_dataset(token, cloud_dataset_id)
    if not success:
        error_msg = dataset_info.get('message', 'Unknown error') if isinstance(dataset_info, dict) else str(dataset_info)
        raise RuntimeError(f'Failed to get dataset: {error_msg}')

    # Check if dataset has files
    if not isinstance(dataset_info, dict):
        if file_uuids is not None and len(file_uuids) > 0:
            raise RuntimeError('No files found in the dataset despite files requested.')
        return  # Nothing to do

    files = dataset_info.get('files', None)

    # Handle case where files field is missing or empty
    if files is None or (isinstance(files, list) and len(files) == 0):
        if file_uuids is not None and len(file_uuids) > 0:
            raise RuntimeError('No files found in the dataset despite files requested.')
        return  # Nothing to do

    # If files is not a list, it might be a struct or dict - convert to list
    if not isinstance(files, list):
        # In MATLAB, files might be a struct array
        # In Python API response, it's typically a list
        if isinstance(files, dict):
            files = [files]
        else:
            if file_uuids is not None and len(file_uuids) > 0:
                raise RuntimeError('No files found in the dataset despite files requested.')
            return

    # Filter files to download
    files = _filter_files_to_download(files, file_uuids)

    num_files = len(files)
    if verbose:
        print(f'Will download {num_files} files...')

    # Download each file
    for i, file_entry in enumerate(files):
        if verbose:
            _display_progress(i + 1, num_files)

        file_uid = file_entry.get('uid', '')
        exists_on_cloud = file_entry.get('uploaded', False)

        if not exists_on_cloud:
            warnings.warn(f'File with uuid "{file_uid}" does not exist on the cloud, skipping...')
            continue

        target_filepath = os.path.join(target_folder, file_uid)

        # Skip if file already exists locally
        if os.path.isfile(target_filepath):
            if verbose:
                print(f'File {i + 1} already exists locally, skipping...')
            continue

        # Get file details to obtain download URL
        success, answer, _, _ = files_api.get_file_details(token, cloud_dataset_id, file_uid)
        if not success:
            error_msg = answer.get('message', 'Unknown error') if isinstance(answer, dict) else str(answer)
            warnings.warn(f'Failed to get file details: {error_msg}')
            continue

        download_url = answer.get('downloadUrl', '')

        if not download_url:
            warnings.warn(f'No download URL available for file {file_uid}')
            continue

        # Download the file
        try:
            urllib.request.urlretrieve(download_url, target_filepath)
        except Exception as e:
            if abort_on_error:
                raise
            else:
                warnings.warn(f'Download failed for file {i + 1}: {str(e)}')

    if verbose:
        print('File download complete.')


def _filter_files_to_download(
    files: List[Dict],
    file_uuids: Optional[List[str]]
) -> List[Dict]:
    """
    Filter files list to only include requested file UIDs.

    Args:
        files: List of file info dictionaries
        file_uuids: List of file UIDs to filter by, or None for all files

    Returns:
        Filtered list of file info dictionaries

    Raises:
        AssertionError: If filtered list doesn't match requested UIDs
    """
    if file_uuids is None or len(file_uuids) == 0:
        return files

    # Get all file UIDs from files list
    all_file_uids = [f.get('uid', '') for f in files]

    # Find indices of matching files (preserve order)
    filtered_files = []
    for file_entry in files:
        if file_entry.get('uid', '') in file_uuids:
            filtered_files.append(file_entry)

    # Verify we found all requested files
    filtered_uids = sorted([f.get('uid', '') for f in filtered_files])
    requested_uids = sorted(file_uuids)

    assert filtered_uids == requested_uids, \
        'Expected filtered files list to match IDs for filtering.'

    return filtered_files


def _display_progress(current_file_number: int, total_file_number: int) -> None:
    """
    Display progress for file download.

    Args:
        current_file_number: Current file number being downloaded
        total_file_number: Total number of files to download
    """
    percent_finished = round((current_file_number / total_file_number) * 100)

    print(f'Downloading file {current_file_number} of {total_file_number} '
          f'({percent_finished}% complete) ...')
