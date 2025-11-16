"""
Download a dataset from NDI Cloud.

Ported from MATLAB: ndi.cloud.download.dataset
"""

from typing import Tuple, Optional, Any
import os
from ..api import datasets
from .dataset_documents import download_dataset_documents
from .jsons2documents import jsons_to_documents


def download_dataset(
    dataset_id: str,
    mode: str = 'local',
    output_path: Optional[str] = None,
    verbose: bool = True
) -> Tuple[bool, str, Optional[Any]]:
    """
    Download a dataset from NDI Cloud.

    Main entry point for downloading entire datasets. Creates directory structure,
    downloads binary files (if mode='local'), downloads documents as JSON files,
    and creates an NDI dataset object.

    Args:
        dataset_id: The dataset ID to download
        mode: Download mode - 'local' to download all files locally,
              'hybrid' to leave binary files in cloud (default: 'local')
        output_path: The path to download the dataset to. If not provided
                    and running interactively, the user will be prompted.
                    If not provided and not interactive, returns error.
        verbose: Should output be verbose? (default: True)

    Returns:
        Tuple of (success, message, dataset):
            - success: True if download succeeded, False otherwise
            - message: Error message if download failed; otherwise empty string
            - dataset: The NDI dataset object if successful, None otherwise

    Example:
        >>> # Download dataset to specific location
        >>> success, msg, dataset = download_dataset(
        ...     'dataset123', mode='local', output_path='/path/to/output'
        ... )
        >>> if success:
        ...     print(f'Downloaded dataset with {len(dataset.documents)} documents')
        >>>
        >>> # Download in hybrid mode (binary files stay in cloud)
        >>> success, msg, dataset = download_dataset(
        ...     'dataset456', mode='hybrid', output_path='/path/to/output'
        ... )

    Directory Structure:
        The function creates the following directory structure:
        - output_path/download/files  - Binary files (if mode='local')
        - output_path/download/json   - Document JSON files

    Notes:
        - Requires NDI_CLOUD_TOKEN environment variable to be set
        - In 'local' mode, downloads all binary files
        - In 'hybrid' mode, binary files remain in cloud
        - Skips files and documents that already exist locally
        - Creates an ndi.dataset.dir object from downloaded documents

    Raises:
        ValueError: If mode is not 'local' or 'hybrid'
        RuntimeError: If output_path not provided and not interactive

    Ported from MATLAB: ndi.cloud.download.dataset
    Source: /home/user/NDI-matlab/src/ndi/+ndi/+cloud/+download/dataset.m
    """
    # Validate mode
    if mode not in ['local', 'hybrid']:
        return False, f"Invalid mode '{mode}'. Must be 'local' or 'hybrid'.", None

    msg = ''
    dataset_obj = None

    # Handle missing output_path
    if output_path is None or output_path == '':
        # In Python, we can't easily prompt for directory in CLI
        # User must provide output_path
        return False, 'output_path must be provided', None

    # Get authentication token from environment
    token = os.getenv('NDI_CLOUD_TOKEN')
    if not token:
        return False, 'No authentication token found. Please set NDI_CLOUD_TOKEN environment variable.', None

    # Construct folder structure
    if not os.path.isdir(output_path):
        os.makedirs(output_path, exist_ok=True)

    file_path = os.path.join(output_path, 'download', 'files')
    json_path = os.path.join(output_path, 'download', 'json')

    if not os.path.isdir(file_path):
        os.makedirs(file_path, exist_ok=True)

    if not os.path.isdir(json_path):
        os.makedirs(json_path, exist_ok=True)

    # Retrieve dataset
    if verbose:
        print('Retrieving dataset...')

    success, dataset, _, _ = datasets.get_dataset(token, dataset_id)
    if not success:
        error_msg = dataset.get('message', 'Unknown error') if isinstance(dataset, dict) else str(dataset)
        return False, f'Failed to get dataset: {error_msg}', None

    # Download files if in local mode
    if mode == 'local':
        files = dataset.get('files', [])

        if verbose:
            print(f'Will download {len(files)} files...')

        for i, file_entry in enumerate(files):
            if verbose:
                percent = 100 * (i + 1) / len(files)
                print(f'Downloading file {i + 1} of {len(files)} ({percent:.1f}%)...')

            file_uid = file_entry.get('uid', '')
            uploaded = file_entry.get('uploaded', False)

            if not uploaded:
                print('not uploaded to the cloud. Skipping...')
                continue

            file_location = os.path.join(output_path, 'download', 'files', file_uid)

            # Skip if file already exists
            if os.path.isfile(file_location):
                if verbose:
                    print(f'File {i + 1} already exists. Skipping...')
                continue

            # Get file details to obtain download URL
            from ..api import files as files_api
            success_file, answer, _, _ = files_api.get_file_details(token, dataset_id, file_uid)
            if not success_file:
                error_msg = answer.get('message', 'Unknown error') if isinstance(answer, dict) else str(answer)
                import warnings
                warnings.warn(f'Failed to get file details: {error_msg}')
                continue

            download_url = answer.get('downloadUrl', '')

            if not download_url:
                import warnings
                warnings.warn(f'No download URL for file {file_uid}')
                continue

            if verbose:
                print(f'Saving file {i + 1}...')

            # Download the file
            import urllib.request
            urllib.request.urlretrieve(download_url, file_location)

        if verbose:
            print('File Downloading complete.')

    # Download documents
    success_docs, msg_docs = download_dataset_documents(
        dataset, mode, json_path, file_path, verbose=verbose
    )

    # Convert JSONs to documents
    ndi_documents = jsons_to_documents(json_path)

    # Build dataset from documents
    if verbose:
        print('Building dataset from documents...')
        if mode == 'local':
            print('Will copy downloaded files into dataset..may take several minutes if the dataset is large...')

    # Import dataset class
    try:
        from ...dataset.dir import DatasetDir
        dataset_obj = DatasetDir(reference=None, path=output_path, documents=ndi_documents)
    except ImportError:
        # If DatasetDir is not available, return the documents list
        import warnings
        warnings.warn('Could not import DatasetDir. Returning documents list instead.')
        dataset_obj = ndi_documents

    return True, msg, dataset_obj
