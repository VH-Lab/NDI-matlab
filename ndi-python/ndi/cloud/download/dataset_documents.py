"""
Download dataset documents from NDI Cloud.

Ported from MATLAB: ndi.cloud.download.datasetDocuments
"""

from typing import Tuple, Dict, Any
import os
import json
from ...util.json_utils import rehydrate_json_nan_null
from ..api import documents as docs_api
from ...document import Document
from .internal.set_file_info import set_file_info as set_file_info_util


def download_dataset_documents(
    dataset: Dict[str, Any],
    mode: str,
    json_path: str,
    file_path: str,
    verbose: bool = True
) -> Tuple[bool, str]:
    """
    Download dataset documents from NDI Cloud.

    Downloads all documents for a dataset to JSON files. Each document is
    saved as a separate JSON file named by its document ID.

    Args:
        dataset: The dataset structure returned from ndi.cloud.api.datasets.get_dataset
        mode: Download mode - 'local' to download all files locally,
              'hybrid' to leave binary files in cloud
        json_path: Location to save document JSON files (must be an existing directory)
        file_path: Location to save binary files (must be an existing directory)
        verbose: Should output be verbose? (default: True)

    Returns:
        Tuple of (success, message):
            - success: True if download succeeded, False otherwise
            - message: Error message if download failed; otherwise empty string

    Example:
        >>> from ndi.cloud.api import datasets
        >>> success, dataset_info, _, _ = datasets.get_dataset(token, 'dataset123')
        >>> if success:
        ...     b, msg = download_dataset_documents(
        ...         dataset_info, 'local', '/path/to/json', '/path/to/files'
        ...     )

    Notes:
        - Skips documents that already exist locally
        - In 'local' mode, updates file paths to point to downloaded files
        - In 'hybrid' mode, sets delete_original and ingest flags to 0
        - Removes the 'id' field from each document before saving

    Ported from MATLAB: ndi.cloud.download.datasetDocuments
    Source: /home/user/NDI-matlab/src/ndi/+ndi/+cloud/+download/datasetDocuments.m
    """
    # Validate mode
    if mode not in ['local', 'hybrid']:
        return False, f"Invalid mode '{mode}'. Must be 'local' or 'hybrid'."

    # Validate paths exist
    if not os.path.isdir(json_path):
        return False, f"JSON path does not exist or is not a directory: {json_path}"
    if not os.path.isdir(file_path):
        return False, f"File path does not exist or is not a directory: {file_path}"

    msg = ''
    success = True

    # Get authentication token from environment
    token = os.getenv('NDI_CLOUD_TOKEN')
    if not token:
        return False, 'No authentication token found. Please set NDI_CLOUD_TOKEN environment variable.'

    # Get document list from dataset
    documents_list = dataset.get('documents', [])

    if verbose:
        print(f'Will download {len(documents_list)} documents...')

    # Take an inventory of documents we already have
    here_already = []
    for i, document_id in enumerate(documents_list):
        json_file_path = os.path.join(json_path, f'{document_id}.json')
        if os.path.isfile(json_file_path):
            here_already.append(i)

    # Download each document
    for i, document_id in enumerate(documents_list):
        if verbose:
            percent = 100 * (i + 1) / len(documents_list)
            print(f'Downloading document {i + 1} of {len(documents_list)} ({percent:.1f}%)...')

        json_file_path = os.path.join(json_path, f'{document_id}.json')

        # Skip if already exists
        if os.path.isfile(json_file_path):
            if verbose:
                print(f'Document {i + 1} already exists. Skipping...')
            continue

        # Get the document from the API
        doc_success, doc_struct, _, _ = docs_api.get_document(
            token, dataset['x_id'], document_id
        )

        if not doc_success:
            error_msg = doc_struct.get('message', 'Unknown error') if isinstance(doc_struct, dict) else str(doc_struct)
            import warnings
            warnings.warn(f'Failed to get document: {error_msg}')
            continue

        if verbose:
            print(f'Saving document {i + 1}...')

        # Remove the 'id' field if present (API field, not part of document)
        if 'id' in doc_struct:
            doc_struct = {k: v for k, v in doc_struct.items() if k != 'id'}

        # Set file info based on mode
        doc_struct = _set_file_info(doc_struct, mode, file_path)

        # Create Document object
        document_obj = Document(doc_struct)

        # Save the document as JSON file
        # Convert document to dict format for JSON serialization
        doc_dict = {'document_properties': document_obj.document_properties}

        # Convert to JSON string with NaN handling
        json_string = json.dumps(doc_dict, indent=2)

        # Write to file
        with open(json_file_path, 'w') as f:
            f.write(json_string)

    return success, msg


def _set_file_info(doc_struct: Dict[str, Any], mode: str, filepath: str) -> Dict[str, Any]:
    """
    Set file info parameters for different modes.

    Given a document structure downloaded from the API, set the 'delete_original'
    and 'ingest' fields as appropriate to the mode.

    Args:
        doc_struct: Document structure from ndi.cloud.api.documents.get_document
        mode: 'local' or 'hybrid'
        filepath: Location of any locally downloaded files (for 'local' mode)

    Returns:
        Updated document structure

    Notes:
        - In 'local' mode, replaces file_info with local file paths
        - In 'hybrid' mode, sets delete_original and ingest to 0

    Ported from MATLAB: ndi.cloud.download.internal.setFileInfo
    Source: /home/user/NDI-matlab/src/ndi/+ndi/+cloud/+download/+internal/setFileInfo.m
    """
    new_doc_struct = doc_struct.copy()

    if 'files' not in doc_struct:
        return new_doc_struct

    files = doc_struct.get('files', {})
    file_info = files.get('file_info', [])

    if not file_info:
        return new_doc_struct

    if mode == 'local':
        # For local mode, create a document and rebuild file info with local paths
        my_doc = Document(doc_struct)
        my_doc.document_properties['files'] = {'file_info': []}

        for file_entry in file_info:
            if 'locations' in file_entry and file_entry['locations']:
                file_uid = file_entry['locations'][0].get('uid', '')
                filename = file_entry.get('name', '')
                file_location = os.path.join(filepath, file_uid)

                # Add file to document (this will create proper file_info structure)
                # Note: In Python, we need to implement add_file method
                # For now, manually construct the file_info
                new_file_entry = {
                    'name': filename,
                    'locations': [{
                        'uid': file_uid,
                        'file_path': file_location,
                        'delete_original': 1,
                        'ingest': 1
                    }]
                }
                my_doc.document_properties['files']['file_info'].append(new_file_entry)

        new_doc_struct = my_doc.document_properties

    else:  # hybrid mode
        # Set delete_original and ingest to 0 for all file locations
        new_files = new_doc_struct.get('files', {}).copy()
        new_file_info = []

        for file_entry in file_info:
            new_entry = file_entry.copy()
            if 'locations' in file_entry:
                new_locations = []
                for location in file_entry['locations']:
                    new_location = location.copy()
                    new_location['delete_original'] = 0
                    new_location['ingest'] = 0
                    new_locations.append(new_location)
                new_entry['locations'] = new_locations
            new_file_info.append(new_entry)

        new_files['file_info'] = new_file_info
        new_doc_struct['files'] = new_files

    return new_doc_struct
