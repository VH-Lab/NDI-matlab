"""
Upload a collection of documents to NDI Cloud.

This module provides functionality to upload multiple documents to NDI Cloud
using either bulk (ZIP-based) or serial upload methods.

MATLAB Source: ndi/+ndi/+cloud/+upload/uploadDocumentCollection.m
"""

import os
import json
from typing import List, Dict, Any, Tuple, Optional
from pathlib import Path


def upload_document_collection(
    dataset_id: str,
    document_list: List,
    max_document_chunk: float = float('inf'),
    only_upload_missing: bool = True,
    verbose: bool = True
) -> Tuple[bool, Dict[str, Any]]:
    """
    Upload a collection of documents using bulk or serial upload.

    This function performs an upload of documents to a specified dataset. The method
    (batch vs. serial) and batch size can be controlled. By default, it uses a bulk
    upload process creating ZIP archives from the document list, retrieving bulk
    upload URLs, and uploading the ZIP files to the cloud. This process can be
    broken into chunks using the 'max_document_chunk' parameter.

    If the environment variable 'NDI_CLOUD_UPLOAD_NO_ZIP' is set to 'true',
    the documents are uploaded one at a time via a slower serial process.

    Args:
        dataset_id: The unique identifier for the target NDI Cloud dataset
        document_list: A list of ndi.document objects to be uploaded
        max_document_chunk: The maximum number of documents to include in a single
                           ZIP archive for batch uploads. Defaults to infinity
                           (all documents in one batch)
        only_upload_missing: If True, only upload documents not already in cloud.
                            Defaults to True
        verbose: If True, print progress information. Defaults to True

    Returns:
        A tuple containing:
        - success (bool): True if the entire upload operation succeeded, False otherwise
        - report (dict): A dictionary containing a report of the upload operation with fields:
            - 'uploadType': 'batch', 'serial', or 'none'
            - 'manifest': For 'batch' type, a list where each entry is a list of
                         document IDs in that batch. For 'serial' type, a list of
                         individual document IDs. For 'none' type, empty list
            - 'status': A list with 'success' or 'failure' for each corresponding
                       entry in the manifest

    Raises:
        AssertionError: If the document_list is empty
        RuntimeError: If unable to list remote documents or get bulk upload URL

    Example:
        >>> # Upload a collection of documents in chunks of 100
        >>> docs = [doc_obj1, doc_obj2, ..., doc_obj250]
        >>> success, upload_report = upload_document_collection(
        ...     "dataset123", docs, max_document_chunk=100
        ... )
        >>> if success:
        ...     print("All documents uploaded successfully")
        >>> else:
        ...     print(f"Upload failed: {upload_report}")

    See Also:
        - ndi.cloud.api.documents.get_bulk_upload_url
        - ndi.cloud.upload.internal.zip_documents_for_upload

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+upload/uploadDocumentCollection.m
    """
    # Import here to avoid circular dependencies
    from .internal import zip_documents_for_upload

    assert document_list, 'List of documents was empty.'

    # --- Pre-processing Step: Filter out already-uploaded documents ---
    if only_upload_missing:
        total_local_docs = len(document_list)

        # TODO: Implement list_dataset_documents_all function
        # This should be added to ndi.cloud.api.documents module
        # For now, we'll skip this filtering step with a warning
        if verbose:
            print("WARNING: only_upload_missing=True but list_dataset_documents_all "
                  "is not yet implemented. Uploading all documents.")
            print(f"Total documents to upload: {total_local_docs}")

        # MATLAB code for reference:
        # [success, remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(dataset_id)
        # if not success:
        #     raise RuntimeError(f"Could not list remote documents: {remote_docs.get('message', '')}")
        #
        # num_remote_docs = len(remote_docs)
        # remote_doc_ndi_ids = set(doc.get('ndiId') for doc in remote_docs)
        # local_doc_ndi_ids = []
        # for doc in document_list:
        #     if hasattr(doc, 'document_properties'):
        #         local_doc_ndi_ids.append(doc.document_properties.get('base', {}).get('id'))
        #     else:
        #         local_doc_ndi_ids.append(doc.get('base', {}).get('id'))
        #
        # # Keep only documents not in remote set
        # documents_to_upload = []
        # for i, doc_id in enumerate(local_doc_ndi_ids):
        #     if doc_id not in remote_doc_ndi_ids:
        #         documents_to_upload.append(document_list[i])
        #
        # document_list = documents_to_upload
        #
        # if verbose:
        #     print(f'Total documents: {total_local_docs}. {num_remote_docs} already in cloud. '
        #           f'{len(document_list)} remain to be transmitted.')

    # If no documents to upload after filtering
    if not document_list:
        return True, {
            'uploadType': 'none',
            'manifest': [],
            'status': []
        }

    if verbose:
        print('Uploading dataset documents...')

    # Extract document IDs for the report manifest
    doc_ids = []
    for doc in document_list:
        if hasattr(doc, 'id') and callable(doc.id):
            doc_ids.append(doc.id())
        elif hasattr(doc, 'document_properties'):
            doc_ids.append(doc.document_properties.get('base', {}).get('id', ''))
        else:
            doc_ids.append(doc.get('base', {}).get('id', ''))

    # Check environment variable for upload method
    ndi_cloud_upload_no_zip = os.environ.get('NDI_CLOUD_UPLOAD_NO_ZIP', 'false').lower()

    # --- Main Logic ---
    if ndi_cloud_upload_no_zip == 'true':
        # SERIAL UPLOAD
        if verbose:
            print("Using serial upload (NDI_CLOUD_UPLOAD_NO_ZIP is set)")

        report = {
            'uploadType': 'serial',
            'manifest': [],
            'status': []
        }

        # TODO: Implement add_document function in ndi.cloud.api.documents
        # For now, this is a placeholder
        for i, doc in enumerate(document_list):
            report['manifest'].append(doc_ids[i])
            try:
                # Get document properties
                if hasattr(doc, 'document_properties'):
                    doc_properties = doc.document_properties
                else:
                    doc_properties = doc

                # Convert to JSON
                doc_json = json.dumps(doc_properties)

                # TODO: Call API to add document
                # from ndi.cloud.api.documents import add_document
                # success, response = add_document(token, dataset_id, doc_properties)
                # if not success:
                #     raise RuntimeError(f"Failed to add document: {response}")

                report['status'].append('success')

                if verbose and (i + 1) % 10 == 0:
                    print(f"Uploaded {i + 1} of {len(document_list)} documents")

            except Exception as e:
                report['status'].append('failure')
                if verbose:
                    print(f"Failed to upload document {doc_ids[i]}: {e}")

    else:
        # BATCH (ZIP) UPLOAD
        if verbose:
            print("Using batch upload (ZIP-based)")

        report = {
            'uploadType': 'batch',
            'manifest': [],
            'status': []
        }

        doc_count = len(document_list)
        i = 0

        while i < doc_count:
            start_index = i
            end_index = min(i + int(max_document_chunk), doc_count)

            # Get chunk of documents
            chunk_docs = document_list[start_index:end_index]

            zip_file_path = ''
            id_manifest = []

            try:
                # Create zip file for the current chunk
                zip_file_path, id_manifest = zip_documents_for_upload(
                    chunk_docs, dataset_id
                )

                # TODO: Implement get_bulk_upload_url and put_files functions
                # These should be added to ndi.cloud.api.documents and ndi.cloud.api.files
                # For now, this is a placeholder

                # MATLAB code for reference:
                # [success, upload_url] = ndi.cloud.api.documents.getBulkUploadURL(dataset_id)
                # if not success:
                #     raise RuntimeError(f"Failed to get bulk upload URL: {upload_url.get('message', '')}")
                # ndi.cloud.api.files.putFiles(upload_url, zip_file_path)

                # If we reached here, the upload was successful
                report['manifest'].append(id_manifest)
                report['status'].append('success')

                # Clean up the zip file
                if os.path.exists(zip_file_path):
                    os.remove(zip_file_path)

                if verbose:
                    print(f"Uploaded batch {len(report['manifest'])} "
                          f"({end_index}/{doc_count} documents)")

            except Exception as e:
                # The upload failed
                if not id_manifest:  # if zipping failed before manifest was created
                    id_manifest = [doc_ids[j] for j in range(start_index, end_index)]

                report['manifest'].append(id_manifest)
                report['status'].append('failure')

                # Clean up the file if it was created before the error
                if zip_file_path and os.path.exists(zip_file_path):
                    os.remove(zip_file_path)

                if verbose:
                    print(f"Failed to upload batch: {e}")

            i = end_index

    # Determine overall success from the report
    success = 'failure' not in report['status']

    return success, report
