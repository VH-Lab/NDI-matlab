"""
Scan documents for files and information needed for upload to NDI Cloud.

This module provides functionality to scan a local NDI session and identify
which documents and files need to be uploaded to the cloud.

MATLAB Source: ndi/+ndi/+cloud/+upload/scanForUpload.m
"""

import os
from typing import List, Dict, Tuple, Any
from pathlib import Path


def scan_for_upload(
    session: 'ndi.session',
    documents: List,
    is_new: bool,
    dataset_id: str = '',
    verbose: bool = True
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], float]:
    """
    Scan documents for files and information needed for upload.

    This function examines a list of documents from an NDI session and determines
    which documents and associated files need to be uploaded to the cloud. For
    existing datasets, it compares against already-uploaded content to avoid
    redundant uploads.

    Args:
        session: An ndi.session object containing the documents
        documents: Documents returned by searching the session using database_search
        is_new: True if this is a new dataset with empty documents and files,
               False otherwise
        dataset_id: The dataset id. Empty string if it is a new dataset
        verbose: If True, print progress information. Defaults to True

    Returns:
        A tuple containing:
        - doc_json_struct: A list of dictionaries with fields:
            - 'docid': The document id
            - 'is_uploaded': A flag indicating if the document is uploaded
        - doc_file_struct: A list of dictionaries with fields:
            - 'uid': The unique identifier of the file
            - 'name': The name of the file
            - 'docid': The document id that the file is associated with
            - 'bytes': The size of the file in bytes
            - 'is_uploaded': A flag indicating if the file is uploaded
        - total_size: The total size of the files to upload in KB

    Example:
        >>> from ndi.cloud.upload import scan_for_upload
        >>> # Search for all documents in session
        >>> docs = session.database_search(ndi.query('', 'isa', 'base'))
        >>> doc_structs, file_structs, total_kb = scan_for_upload(
        ...     session, docs, is_new=False, dataset_id="dataset123"
        ... )
        >>> print(f"Found {len(doc_structs)} documents and {len(file_structs)} files")
        >>> print(f"Total size: {total_kb:.2f} KB")

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+upload/scanForUpload.m
    """
    if verbose:
        print('Loading documents...')

    doc_json_struct = []
    doc_file_struct = []
    total_size = 0.0  # in KB

    # Track all document IDs for later comparison
    all_doc_ids = []

    # Explicitly open the database before scanning all the files to upload.
    # This process will run a large number of queries to the database, so keep
    # it open till finished.

    # TODO: Implement open_database() method for session
    # In MATLAB: [db_cleanup_obj, ~] = S.open_database()
    # This returns a cleanup object that closes the database when it goes out of scope

    for i, doc in enumerate(documents):
        if verbose and ((i + 1) % 10 == 0 or i == len(documents) - 1):
            print(f'Working on document {i + 1} of {len(documents)}')

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

        all_doc_ids.append(doc_id)

        # Add document to json struct
        doc_json_struct.append({
            'docid': doc_id,
            'is_uploaded': False
        })

        # Process files associated with this document
        if isinstance(doc_properties, dict):
            files_info = doc_properties.get('files', {})
            file_list = files_info.get('file_list', []) if files_info else []
        else:
            files_info = getattr(doc_properties, 'files', None)
            file_list = getattr(files_info, 'file_list', []) if files_info else []

        for file_name in file_list:
            j = 1
            is_finished = False

            while not is_finished:  # we could potentially read a series of files
                if file_name.endswith('#'):  # this file is a series of files
                    filename_here = f"{file_name[:-1]}{j}"
                else:
                    filename_here = file_name
                    is_finished = True  # only 1 file

                # Check if file exists in database
                # TODO: Implement database_existbinarydoc method for session
                # In MATLAB: [file_exists, full_file_path] = S.database_existbinarydoc(ndi_doc_id, filename_here)

                # Placeholder: Assume file exists in session path
                files_dir = os.path.join(session.path, '.ndi', 'files') if hasattr(session, 'path') else ''
                # We can't determine the actual UID without the database method, so skip for now
                file_exists = False
                full_file_path = ''

                if not file_exists:
                    is_finished = True
                    full_file_path = ''

                j += 1

                if full_file_path:
                    # Extract UID from file path (filename without extension)
                    uid = Path(full_file_path).stem

                    # Get file size
                    file_bytes = os.path.getsize(full_file_path) if os.path.exists(full_file_path) else 0
                    file_size_kb = file_bytes / 1024

                    doc_file_struct.append({
                        'uid': uid,
                        'name': file_name,
                        'docid': doc_id,
                        'bytes': file_bytes,
                        'is_uploaded': False
                    })

                    total_size += file_size_kb

    # If this is not a new dataset, check what's already uploaded
    if not is_new and dataset_id:
        # TODO: Implement list_dataset_documents_all and get_dataset functions
        # These should be added to ndi.cloud.api.documents and ndi.cloud.api.datasets

        # MATLAB code for reference:
        # [success, doc_summary] = ndi.cloud.api.documents.listDatasetDocumentsAll(dataset_id)
        # if not success:
        #     raise RuntimeError(f"Failed to list documents: {doc_summary.get('message', '')}")
        #
        # [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id)
        # if not success:
        #     raise RuntimeError(f"Failed to get dataset: {dataset.get('message', '')}")

        # Placeholder: Mark all as not uploaded
        if verbose:
            print("WARNING: Cloud API functions not yet implemented. "
                  "Cannot check for already-uploaded documents.")

        # MATLAB logic for marking already-uploaded documents:
        # already_uploaded_docs = []
        # if doc_summary:
        #     already_uploaded_docs = [doc.get('ndiId') for doc in doc_summary]
        #
        # # Find documents that still need to be uploaded
        # docs_to_upload = set(all_doc_ids) - set(already_uploaded_docs)
        #
        # # Mark documents as uploaded if they're already in cloud
        # for doc_struct in doc_json_struct:
        #     if doc_struct['docid'] not in docs_to_upload:
        #         doc_struct['is_uploaded'] = True
        #
        # # Check file upload status
        # file_map = {}
        # for file_info in dataset.get('files', []):
        #     file_map[file_info['uid']] = file_info.get('uploaded', False)
        #
        # # Mark files as uploaded and adjust total size
        # for file_struct in doc_file_struct:
        #     if file_struct['uid'] in file_map and file_map[file_struct['uid']]:
        #         file_struct['is_uploaded'] = True
        #         total_size -= file_struct['bytes'] / 1024

    return doc_json_struct, doc_file_struct, total_size
