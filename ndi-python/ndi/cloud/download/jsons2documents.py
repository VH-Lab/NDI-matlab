"""
Convert JSON files to NDI documents.

Ported from MATLAB: ndi.cloud.download.jsons2documents
"""

from typing import List
import os
import json
import glob
from ...document import Document
from ...util.json_utils import rehydrate_json_nan_null


def jsons_to_documents(json_path: str) -> List[Document]:
    """
    Convert JSON files in a directory to NDI Document objects.

    Reads all .json files in the specified directory and converts them
    to NDI Document objects.

    Args:
        json_path: Path to directory containing JSON document files

    Returns:
        List of Document objects

    Raises:
        ValueError: If json_path doesn't exist or is not a directory

    Example:
        >>> docs = jsons_to_documents('/path/to/json/files')
        >>> print(f'Loaded {len(docs)} documents')

    Ported from MATLAB: ndi.cloud.download.jsons2documents
    """
    if not os.path.exists(json_path):
        raise ValueError(f'JSON path does not exist: {json_path}')

    if not os.path.isdir(json_path):
        raise ValueError(f'JSON path is not a directory: {json_path}')

    # Find all JSON files in the directory
    json_files = glob.glob(os.path.join(json_path, '*.json'))

    if not json_files:
        return []

    documents = []

    for json_file in json_files:
        try:
            # Read JSON file
            with open(json_file, 'r') as f:
                json_string = f.read()

            # Rehydrate JSON (handle NaN/null values)
            json_rehydrated = rehydrate_json_nan_null(json_string)
            doc_struct = json.loads(json_rehydrated)

            # Create Document from struct
            doc = Document()
            if 'document_properties' in doc_struct:
                doc.document_properties = doc_struct['document_properties']
            else:
                # Legacy format: struct IS the document_properties
                doc.document_properties = doc_struct

            documents.append(doc)

        except Exception as e:
            import warnings
            warnings.warn(f'Failed to load document from {json_file}: {e}')
            continue

    return documents
