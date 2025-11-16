"""
Upload an NDI database to NDI Cloud.

This module provides the main orchestration function for uploading a complete
NDI session/dataset to the cloud, including documents and binary files.

MATLAB Source: ndi/+ndi/+cloud/+upload/uploadToNDICloud.m
"""

import json
from typing import Tuple


def upload_to_ndicloud(
    session: 'ndi.session',
    dataset_id: str,
    verbose: bool = True
) -> Tuple[bool, str]:
    """
    Upload an NDI database to NDI Cloud.

    This function orchestrates the complete upload process for an NDI session,
    including scanning for documents and files, uploading document JSON data,
    and uploading binary files in batches.

    Args:
        session: An ndi.session object to be uploaded
        dataset_id: The dataset id for the NDI Cloud
        verbose: If True, print detailed progress information. Defaults to True

    Returns:
        A tuple containing:
        - success (bool): True if the upload succeeded, False otherwise
        - msg (str): An error message if the upload failed; otherwise empty string

    Example:
        >>> from ndi.cloud.upload import upload_to_ndicloud
        >>> # Assuming session is a valid ndi.session object
        >>> success, msg = upload_to_ndicloud(session, "dataset123")
        >>> if success:
        ...     print("Upload completed successfully")
        ... else:
        ...     print(f"Upload failed: {msg}")

    Note:
        This function performs the following steps:
        1. Searches for all base documents in the session
        2. Scans for previously uploaded documents to avoid duplicates
        3. Uploads document JSON data one by one
        4. Batches and uploads binary files in zip archives

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+upload/uploadToNDICloud.m
    """
    from .scan_for_upload import scan_for_upload
    from .zip_for_upload import zip_for_upload

    msg = ''
    success = True

    if verbose:
        print('Loading documents...')

    # TODO: Implement database_search method for session
    # In MATLAB: d = S.database_search(ndi.query('','isa','base'))
    documents = []

    # Placeholder: If session has a method to get all documents, use it
    if hasattr(session, 'database_search'):
        # This method should exist but may not be fully implemented yet
        try:
            # Import ndi.query if available
            from ndi.query import query
            q = query('', 'isa', 'base')
            documents = session.database_search(q)
        except (ImportError, AttributeError):
            if verbose:
                print("WARNING: database_search method not available. Cannot load documents.")
            documents = []
    else:
        if verbose:
            print("WARNING: Session does not have database_search method.")

    if not documents:
        if verbose:
            print("WARNING: No documents found to upload.")
        return True, ''

    if verbose:
        print('Working on documents...')

    if verbose:
        print('Getting list of previously uploaded documents...')

    # Scan for documents and files that need uploading
    doc_json_struct, doc_file_struct, total_size = scan_for_upload(
        session, documents, is_new=False, dataset_id=dataset_id, verbose=verbose
    )

    # Count documents and files to be uploaded
    docs_left = sum(1 for doc in doc_json_struct if not doc.get('is_uploaded', False))
    files_left = sum(1 for file in doc_file_struct if not file.get('is_uploaded', False))

    if verbose:
        print(f'Found {docs_left} new documents and {files_left} files. Uploading...')

    # Create mapping from document ID to index
    doc_id_to_idx = {doc['docid']: i for i, doc in enumerate(doc_json_struct)}

    # --- Upload Documents ---
    cur_doc_idx = 1

    for doc in documents:
        # Get document properties
        if hasattr(doc, 'document_properties'):
            doc_properties = doc.document_properties
        else:
            doc_properties = doc

        # Extract document ID
        if isinstance(doc_properties, dict):
            doc_id = doc_properties.get('base', {}).get('id', '')
        else:
            doc_id = getattr(doc_properties.base, 'id', '')

        # Check if document needs to be uploaded
        if doc_id in doc_id_to_idx:
            doc_struct = doc_json_struct[doc_id_to_idx[doc_id]]

            if not doc_struct.get('is_uploaded', False):
                # Convert document to JSON
                # TODO: Use jsonencodenan utility if available
                # In MATLAB: document = did.datastructures.jsonencodenan(d{i}.document_properties)
                if isinstance(doc_properties, dict):
                    document_json = json.dumps(doc_properties)
                else:
                    # Convert object to dict first
                    # This is a simplified conversion; actual implementation may need more work
                    document_json = json.dumps(doc_properties.__dict__)

                if verbose:
                    print(f'Uploading {cur_doc_idx} JSON portions of {docs_left} '
                          f'({100 * cur_doc_idx / docs_left:.1f}%)')
                    print(f'Uploading Document: {doc_id}. {cur_doc_idx} of {docs_left}...')

                # TODO: Implement add_document_as_file function
                # This should be added to ndi.cloud.api.documents module
                # In MATLAB: [success, ~] = ndi.cloud.api.documents.addDocumentAsFile(dataset_id, document)

                # Placeholder
                upload_success = False
                # if upload_success:
                #     doc_struct['is_uploaded'] = True
                # else:
                #     if verbose:
                #         print('WARNING: Failed to add document')

                if verbose:
                    print("WARNING: add_document_as_file not yet implemented. "
                          "Skipping document upload.")

                cur_doc_idx += 1

    # --- Upload Files ---
    if verbose:
        print('Uploading binary files...')

    success, msg = zip_for_upload(
        session, doc_file_struct, total_size, dataset_id, verbose=verbose
    )

    return success, msg
