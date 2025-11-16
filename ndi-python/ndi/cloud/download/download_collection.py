"""
Download document collections from NDI Cloud with chunking support.

Ported from MATLAB: ndi.cloud.download.downloadDocumentCollection
"""

from typing import List, Optional, Dict, Any
import os
import tempfile
import zipfile
import json
import time
import urllib.request
from ....document import Document
from ..api import datasets, documents as docs_api
from .internal.structs_to_ndi_documents import structs_to_ndi_documents


def download_document_collection(
    dataset_id: str,
    document_ids: Optional[List[str]] = None,
    timeout: float = 20.0,
    chunk_size: int = 2000,
    verbose: bool = True
) -> List[Document]:
    """
    Download a collection of documents from NDI Cloud with automatic chunking.

    To improve performance and avoid server errors with large requests, this
    function automatically splits the list of document IDs into smaller chunks
    and performs a separate download for each chunk.

    Args:
        dataset_id: Unique identifier for the dataset
        document_ids: List of cloud API document identifiers to download.
                     If None or empty, downloads ALL documents in the dataset.
        timeout: Timeout in seconds for each download operation (default: 20.0)
        chunk_size: Maximum number of document IDs per chunk (default: 2000)
        verbose: Print progress messages (default: True)

    Returns:
        List of Document objects

    Raises:
        RuntimeError: If download fails or times out

    Example:
        >>> # Download all documents from a dataset
        >>> docs = download_document_collection("dataset123")
        >>>
        >>> # Download specific documents with larger chunk size
        >>> my_ids = ["id_abc", "id_def", ...]
        >>> docs = download_document_collection("dataset456", my_ids, chunk_size=5000)

    Note:
        If you intend to download all documents and already have the list of
        document IDs, it is more efficient to pass that list directly to
        avoid an extra API call to fetch the list again.

    Ported from MATLAB: ndi.cloud.download.downloadDocumentCollection
    """
    # If user requests all documents, fetch the full list of IDs first
    if document_ids is None or len(document_ids) == 0:
        if verbose:
            print('No document IDs provided; fetching all document IDs from the server...')

        # List all document IDs in the dataset
        from ..sync.internal.list_remote_document_ids import list_remote_document_ids
        id_map = list_remote_document_ids(dataset_id)
        document_ids = id_map.get('apiId', [])

        if not document_ids:
            if verbose:
                print('Dataset has no documents.')
            return []

    # Split the document_ids into chunks for processing
    num_docs = len(document_ids)
    num_chunks = (num_docs + chunk_size - 1) // chunk_size  # Ceiling division

    document_chunks = []
    for i in range(num_chunks):
        start_index = i * chunk_size
        end_index = min((i + 1) * chunk_size, num_docs)
        document_chunks.append(document_ids[start_index:end_index])

    all_document_structs = []
    if verbose:
        print(f'Beginning download of {num_docs} documents in {num_chunks} chunk(s).')

    for c, chunk_doc_ids in enumerate(document_chunks, start=1):
        if verbose:
            print(f'  Processing chunk {c} of {num_chunks} ({len(chunk_doc_ids)} documents)...')

        # Get bulk download URL
        success, download_url, api_reply = docs_api.get_bulk_download_url(
            dataset_id,
            cloud_document_ids=chunk_doc_ids
        )

        if not success:
            raise RuntimeError(f'Failed to get bulk download URL: {api_reply.get("message", "Unknown error")}')

        # Create temporary file for zip download
        temp_zip = tempfile.NamedTemporaryFile(suffix='.zip', delete=False)
        temp_zip_path = temp_zip.name
        temp_zip.close()

        try:
            # Download may not be immediately ready; retry until timeout
            is_finished = False
            start_time = time.time()

            while not is_finished and (time.time() - start_time) < timeout:
                try:
                    urllib.request.urlretrieve(download_url, temp_zip_path)
                    is_finished = True
                except Exception as e:
                    last_error = e
                    time.sleep(1)  # Wait before retrying

            if not is_finished:
                raise RuntimeError(
                    f'Download failed for chunk {c} with error: {last_error}. '
                    f'If this persists, consider increasing the timeout value.'
                )

            # Unzip and process documents from the current chunk
            with zipfile.ZipFile(temp_zip_path, 'r') as zip_ref:
                # Extract to temporary directory
                temp_dir = tempfile.mkdtemp()
                zip_ref.extractall(temp_dir)

                # Find the JSON file (should be the first/only file)
                extracted_files = os.listdir(temp_dir)
                if not extracted_files:
                    raise RuntimeError(f'No files in downloaded zip for chunk {c}')

                json_file = os.path.join(temp_dir, extracted_files[0])

                # Read and parse JSON
                with open(json_file, 'r') as f:
                    json_string = f.read()

                # Rehydrate JSON (handle NaN/null values)
                from ....util.json_utils import rehydrate_json_nan_null
                json_rehydrated = rehydrate_json_nan_null(json_string)
                document_structs = json.loads(json_rehydrated)

                # Append to all_document_structs
                if isinstance(document_structs, list):
                    all_document_structs.extend(document_structs)
                elif isinstance(document_structs, dict):
                    all_document_structs.append(document_structs)

                # Clean up temporary directory
                import shutil
                shutil.rmtree(temp_dir, ignore_errors=True)

        finally:
            # Clean up temporary zip file
            if os.path.exists(temp_zip_path):
                os.remove(temp_zip_path)

    if verbose:
        print(f'Download complete. Converting {len(all_document_structs)} structs to NDI documents...')

    documents = structs_to_ndi_documents(all_document_structs)

    if verbose:
        print('Processing complete.')

    return documents
