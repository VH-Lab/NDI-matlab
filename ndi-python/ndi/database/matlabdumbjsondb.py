"""
NDI MATLABDumbJSONDB Database Backend

Ported from MATLAB: src/ndi/+ndi/+database/+implementations/+database/matlabdumbjsondb.m

Provides a simple JSON file-based database backend with:
- Human-readable JSON document storage
- Simple file-based document management
- Basic versioning support
- No external dependencies beyond Python stdlib

This is the simplest database backend, suitable for small datasets
where human readability and simplicity are priorities.
"""

import os
import json
import fcntl
from typing import List, Optional, Union, Tuple
from pathlib import Path
from .base import Database
from ..document import Document
from ..query import Query


class MATLABDumbJSONDB(Database):
    """
    Simple JSON file-based document database for NDI.

    Stores each document as a separate JSON file in a directory structure.
    This provides human-readable storage and simple file-based management.

    This class is equivalent to MATLAB's:
    ndi.database.implementations.database.matlabdumbjsondb

    Attributes:
        db_path: Path to the database directory
        docs_path: Path to the documents directory
        index_file: Path to the document index file

    Example:
        >>> db = MATLABDumbJSONDB('/path/to/session', 'my_session_id')
        >>> doc = db.newdocument('probe')
        >>> db.add(doc)
        >>> results = db.search(Query('', 'isa', 'probe', ''))

    Notes:
        - Each document is stored as a separate .json file
        - Document IDs are used as filenames
        - An index file tracks all document IDs for faster enumeration
        - No versioning support in this basic version
    """

    def __init__(self, path: str = '', session_unique_reference: str = ''):
        """
        Initialize MATLABDumbJSONDB database.

        Args:
            path: Directory path where the database will be stored
            session_unique_reference: Unique reference for the session
        """
        super().__init__(path, session_unique_reference)

        # Create database directory structure
        self.db_path = Path(path) / 'ndi_database' / 'dumbjsondb'
        self.db_path.mkdir(parents=True, exist_ok=True)

        # Documents directory
        self.docs_path = self.db_path / 'documents'
        self.docs_path.mkdir(exist_ok=True)

        # Index file for tracking all document IDs
        self.index_file = self.db_path / 'index.json'

        # Initialize index if it doesn't exist
        if not self.index_file.exists():
            self._save_index([])

    def _load_index(self) -> List[str]:
        """
        Load the document ID index.

        Returns:
            List of document IDs
        """
        if not self.index_file.exists():
            return []

        try:
            with open(self.index_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            # If index is corrupted, rebuild from files
            return self._rebuild_index()

    def _save_index(self, doc_ids: List[str]) -> None:
        """
        Save the document ID index.

        Args:
            doc_ids: List of document IDs to save
        """
        with open(self.index_file, 'w') as f:
            json.dump(sorted(doc_ids), f, indent=2)

    def _rebuild_index(self) -> List[str]:
        """
        Rebuild the index from existing JSON files.

        Returns:
            List of document IDs
        """
        doc_ids = []
        for doc_file in self.docs_path.glob('*.json'):
            doc_ids.append(doc_file.stem)

        self._save_index(doc_ids)
        return doc_ids

    def _add_to_index(self, doc_id: str) -> None:
        """
        Add a document ID to the index.

        Args:
            doc_id: Document ID to add
        """
        index = self._load_index()
        if doc_id not in index:
            index.append(doc_id)
            self._save_index(index)

    def _remove_from_index(self, doc_id: str) -> None:
        """
        Remove a document ID from the index.

        Args:
            doc_id: Document ID to remove
        """
        index = self._load_index()
        if doc_id in index:
            index.remove(doc_id)
            self._save_index(index)

    def _doc_file_path(self, doc_id: str) -> Path:
        """
        Get the file path for a document.

        Args:
            doc_id: Document ID

        Returns:
            Path to the document JSON file
        """
        # Use a safe filename (replace problematic characters)
        safe_id = doc_id.replace('/', '_').replace('\\', '_')
        return self.docs_path / f"{safe_id}.json"

    def _do_add(self, document: Document, Update: bool = True) -> None:
        """
        Add a document to the database.

        Args:
            document: Document to add
            Update: If True, overwrite existing document (default: True)
        """
        doc_id = document.id()
        doc_file = self._doc_file_path(doc_id)

        # Check if document exists
        if doc_file.exists() and not Update:
            raise ValueError(
                f"Document {doc_id} already exists and Update=False"
            )

        # Write document to JSON file
        with open(doc_file, 'w') as f:
            json.dump(document.document_properties, f, indent=2)

        # Add to index
        self._add_to_index(doc_id)

    def _do_read(self, document_id: str) -> Optional[Document]:
        """
        Read a document from the database.

        Args:
            document_id: Document ID to read

        Returns:
            Document or None if not found
        """
        doc_file = self._doc_file_path(document_id)

        if not doc_file.exists():
            return None

        try:
            with open(doc_file, 'r') as f:
                properties = json.load(f)
            return Document(properties)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error reading document {document_id}: {e}")
            return None

    def _do_remove(self, document_id: str) -> None:
        """
        Remove a document from the database.

        Args:
            document_id: Document ID to remove
        """
        doc_file = self._doc_file_path(document_id)

        if doc_file.exists():
            doc_file.unlink()

        # Remove from index
        self._remove_from_index(document_id)

    def _do_search(self, query: Query) -> List[Document]:
        """
        Search documents in the database.

        Args:
            query: Query object

        Returns:
            List of matching documents
        """
        results = []

        # Load and check each document
        for doc_id in self._load_index():
            doc = self._do_read(doc_id)
            if doc and query.matches(doc):
                results.append(doc)

        return results

    def alldocids(self) -> List[str]:
        """
        Get all document IDs in the database.

        Returns:
            List of document IDs
        """
        return self._load_index()

    def _do_openbinarydoc(self, document_id: str, filename: str):
        """
        Open a binary document file for reading.

        Note: This simple backend doesn't support binary file storage directly.
        Binary files should be referenced by path in the document properties.

        Args:
            document_id: Document ID
            filename: Binary file name

        Returns:
            File handle opened in binary read mode

        Raises:
            NotImplementedError: Binary file support not implemented in basic version
        """
        raise NotImplementedError(
            "MATLABDumbJSONDB does not support binary file storage. "
            "Use MATLABDumbJSONDB2 or SQLiteDatabase for binary file support."
        )

    def _check_exist_binarydoc(self, document_id: str, filename: str) -> Tuple[bool, str]:
        """
        Check if a binary document exists.

        Args:
            document_id: Document ID
            filename: Binary file name

        Returns:
            Tuple of (False, '') - not supported in this backend
        """
        return False, ''
