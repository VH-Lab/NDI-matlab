"""
Internal helper for zipping documents for upload to NDI Cloud.

This module provides functionality to serialize and compress NDI documents
for efficient bulk upload to the cloud.

MATLAB Source: ndi/+ndi/+cloud/+upload/+internal/zip_documents_for_upload.m
"""

import os
import json
import tempfile
import zipfile
from typing import List, Tuple, Optional
from pathlib import Path


def zip_documents_for_upload(
    document_list: List,
    cloud_dataset_id: str,
    target_folder: Optional[str] = None
) -> Tuple[str, List[str]]:
    """
    Serialize and zip a list of documents for upload to NDI Cloud.

    This function takes a list of ndi.document objects, converts them into a
    single JSON string, saves this string to a temporary file, and then compresses
    this file into a zip archive. It returns the path to the zip archive and a
    manifest of the document IDs included.

    Args:
        document_list: A list of ndi.document objects to be included in the zip file
        cloud_dataset_id: The cloud dataset id for naming the zip file
        target_folder: Optional folder where the zip file will be created.
                      Defaults to the system's temporary folder

    Returns:
        A tuple containing:
        - zip_file_path (str): The full path to the generated .zip file
        - id_manifest (List[str]): A list of strings containing the unique
                                   identifiers of the documents included

    Note:
        The user is responsible for deleting the file at zip_file_path once it is no
        longer needed to prevent clutter in the target folder.

    Example:
        >>> from ndi.cloud.upload.internal import zip_documents_for_upload
        >>> # Assuming doc1 and doc2 are valid ndi.document objects
        >>> my_docs = [doc1, doc2]
        >>> zip_path, id_list = zip_documents_for_upload(my_docs, "dataset123")
        >>> # ... code to upload the file at zip_path ...
        >>> os.remove(zip_path)  # Clean up the created zip file

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+upload/+internal/zip_documents_for_upload.m
    """
    # Set target folder to temp if not specified
    if target_folder is None:
        target_folder = tempfile.gettempdir()

    # Ensure target folder exists
    os.makedirs(target_folder, exist_ok=True)

    # Extract document properties and create ID manifest
    document_properties_array = []
    id_manifest = []

    for doc in document_list:
        # Access document properties
        if hasattr(doc, 'document_properties'):
            document_properties_array.append(doc.document_properties)
        else:
            # Assume doc is already a dict of properties
            document_properties_array.append(doc)

        # Extract document ID
        if hasattr(doc, 'id') and callable(doc.id):
            id_manifest.append(doc.id())
        elif hasattr(doc, 'document_properties'):
            # Get ID from document properties
            if isinstance(doc.document_properties, dict):
                id_manifest.append(doc.document_properties.get('base', {}).get('id', ''))
            else:
                id_manifest.append(getattr(doc.document_properties.base, 'id', ''))
        else:
            # Fallback: get from dict structure
            id_manifest.append(doc.get('base', {}).get('id', ''))

    # Convert documents to JSON string with NaN handling
    # Python's json module handles special floats (nan, inf) differently than MATLAB
    # We'll use a custom encoder if needed
    json_str = json.dumps(document_properties_array, indent=2, ensure_ascii=False)

    # Create temporary JSON file
    json_fd, json_filename = tempfile.mkstemp(suffix='.json', dir=target_folder)
    try:
        # Write JSON string to file
        with os.fdopen(json_fd, 'w', encoding='utf-8') as f:
            f.write(json_str)

        # Generate unique identifier for zip file
        import uuid
        zip_fname = str(uuid.uuid4())
        zip_file_path = os.path.join(target_folder, f"{cloud_dataset_id}.{zip_fname}.zip")

        # Create zip archive
        with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            zipf.write(json_filename, arcname=os.path.basename(json_filename))

    finally:
        # Clean up temporary JSON file
        if os.path.exists(json_filename):
            os.remove(json_filename)

    return zip_file_path, id_manifest
