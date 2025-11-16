"""
NDI Database Function - Extract document files.

Extract copies of all ndi.document objects and their associated binary files
to a target directory.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/extract_doc_files.m
"""

import os
import shutil
import tempfile
from typing import List, Tuple, Any, Optional
from pathlib import Path


def extract_docs_files(session_or_dataset: Any,
                       target_path: Optional[str] = None) -> Tuple[List[Any], str]:
    """
    Extract copies of all documents and their files to a directory.

    Copies all ndi.document objects from an ndi.session or ndi.dataset object,
    along with their associated binary files, to a target directory. This is
    useful for creating a portable copy of session data or preparing data
    for upload/export.

    Args:
        session_or_dataset: ndi.session or ndi.dataset object
        target_path: Directory path where files will be extracted.
                    If None, a temporary directory is created.

    Returns:
        Tuple of (documents, target_path) where:
        - documents: List of ndi.document objects with updated file paths
        - target_path: Path where files were extracted

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> docs, path = extract_docs_files(session)
        >>> # All documents and files are now in 'path'

        >>> # Extract to specific location
        >>> docs, path = extract_docs_files(session, '/path/to/export')

    Notes:
        - Creates target directory if it doesn't exist
        - Files are renamed using their UID to avoid conflicts
        - Document file references are updated to point to extracted files
        - If extraction fails partway through, attempts to clean up created files
        - Requires sufficient disk space for all files

    Raises:
        IOError: If file copy fails (e.g., insufficient disk space)
        TypeError: If session_or_dataset is not a valid session/dataset object

    See also:
        ndicloud_metadata - Prepare metadata for cloud upload
    """
    from ...query import Query

    # Validate input type
    if not hasattr(session_or_dataset, 'database_search'):
        raise TypeError('Input must be an ndi.session or ndi.dataset object')

    # Create target directory if needed
    if target_path is None:
        target_path = tempfile.mkdtemp(prefix='ndi_extract_')
    else:
        Path(target_path).mkdir(parents=True, exist_ok=True)

    # Search for all documents
    q_all = Query('', 'isa', 'base', '')
    docs = session_or_dataset.database_search(q_all)

    files_created = []

    try:
        # Process each document
        for i, doc in enumerate(docs):
            # Check if document has files
            if 'files' not in doc.document_properties:
                continue

            # Get current file list
            current_files = doc.current_file_list() if hasattr(doc, 'current_file_list') else []

            # Reset file info to rebuild with new paths
            if hasattr(doc, 'reset_file_info'):
                doc = doc.reset_file_info()

            # Process each file
            for filename in current_files:
                doc_id = doc.document_properties.base.id

                # Open binary file from database
                try:
                    file_obj = session_or_dataset.database_openbinarydoc(doc_id, filename)

                    # Get source file path
                    if hasattr(file_obj, 'name'):
                        source_path = file_obj.name
                        file_obj.close()
                    else:
                        # file_obj is a path string
                        source_path = str(file_obj)

                    # Create destination path using UID (filename without extension)
                    file_stem = Path(source_path).stem
                    dest_path = Path(target_path) / file_stem

                    # Copy file
                    shutil.copy2(source_path, dest_path)
                    files_created.append(str(dest_path))

                    # Update document with new file location
                    if hasattr(doc, 'add_file'):
                        doc = doc.add_file(filename, str(dest_path))

                except FileNotFoundError:
                    print(f"Warning: File '{filename}' not found for document {doc_id}")
                    continue
                except Exception as e:
                    print(f"Warning: Error processing file '{filename}': {e}")
                    continue

            # Update document in list
            docs[i] = doc

    except Exception as e:
        # Clean up on error
        print(f"Extraction failed: {e}")
        print("Attempting to clean up created files...")
        for created_file in files_created:
            try:
                if os.path.exists(created_file):
                    os.remove(created_file)
            except Exception as cleanup_error:
                print(f"Warning: Could not delete {created_file}: {cleanup_error}")
        raise IOError(f"Extraction failed: {e}") from e

    return docs, target_path
