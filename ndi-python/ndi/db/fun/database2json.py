"""
Output contents of an NDI session database to JSON files.

This module provides functionality to export all documents in a session's
database to individual JSON files in a specified output directory.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/database2json.m
"""

import os
import json
from typing import Optional


def database2json(session, output_path: str) -> int:
    """
    Output contents of an ndi.session database to JSON files.

    Finds all documents in the database of an ndi.session object and writes
    them to the folder output_path (full path). Each document is saved as a
    separate JSON file named with its document ID.

    Args:
        session: An ndi.session object
        output_path: Full path to the output directory where JSON files will be written

    Returns:
        int: Number of documents exported

    Raises:
        OSError: If output_path cannot be created or is not writable
        ValueError: If session is None or invalid

    Example:
        >>> from ndi.session import Session
        >>> session = Session('/path/to/session')
        >>> count = database2json(session, '/path/to/export')
        >>> print(f"Exported {count} documents")

    Notes:
        - Creates output_path if it doesn't exist
        - Each document is saved as <document_id>.json
        - Binary files referenced in documents are handled specially:
          - File locations are updated to relative paths
          - Files themselves are NOT copied (only metadata is exported)
        - Uses JSON encoding that handles NaN values properly
    """
    from ndi.query import Query

    # Validate inputs
    if session is None:
        raise ValueError("session cannot be None")

    if not output_path:
        raise ValueError("output_path cannot be empty")

    # Create output directory if it doesn't exist
    os.makedirs(output_path, exist_ok=True)

    # Find all documents in the database
    q = Query('base.id', 'regexp', '(.*)', '')
    docs = session.database_search(q)

    # Ensure docs is a list
    if docs is None:
        docs = []
    elif not isinstance(docs, list):
        docs = [docs]

    # Export each document
    for i, doc in enumerate(docs):
        print(f"Exporting document {i+1}/{len(docs)}: {doc.id()}")

        # Handle binary files if present
        if 'files' in doc.document_properties:
            file_list = doc.document_properties.get('files', {}).get('file_list', [])

            for filename in file_list:
                try:
                    # Try to get binary file info
                    bfile = session.database_openbinarydoc(doc, filename)
                    if bfile:
                        # Update file location to be relative/standalone
                        # Note: We're not copying the actual files, just updating metadata
                        doc = doc.add_file(
                            filename,
                            filename,  # Use just the filename
                            ingest=True,
                            delete_original=False,
                            location_type='file',
                            uid=filename
                        )
                except Exception as e:
                    # If we can't access the binary file, skip it
                    print(f"  Warning: Could not access binary file {filename}: {e}")
                    continue

        # Convert document properties to JSON
        try:
            # Handle NaN values in JSON encoding
            json_str = json.dumps(
                doc.document_properties,
                indent=2,
                default=str,  # Convert non-serializable objects to strings
                allow_nan=True
            )
        except Exception as e:
            print(f"  Warning: Failed to serialize document {doc.id()}: {e}")
            continue

        # Write to file
        output_file = os.path.join(output_path, f"{doc.id()}.json")
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(json_str)
        except Exception as e:
            print(f"  Error writing file {output_file}: {e}")
            continue

    print(f"Exported {len(docs)} documents to {output_path}")
    return len(docs)
