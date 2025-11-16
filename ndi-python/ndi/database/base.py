"""
NDI Database - NoSQL document database for NDI.
"""

import os
import json
import shutil
from typing import List, Optional, Union
from pathlib import Path
from ..document import Document
from ..query import Query
from ..ido import IDO


class Database:
    """
    Abstract NDI Database class for storing and managing documents.

    This is a NoSQL document database that stores documents as JSON files
    with associated binary data files.
    """

    def __init__(self, path: str = '', session_unique_reference: str = ''):
        """
        Create a new database.

        Args:
            path: File system path to the database
            session_unique_reference: Unique reference for the session
        """
        self.path = path
        self.session_unique_reference = session_unique_reference

    def newdocument(self, document_type: str = 'base', **properties) -> Document:
        """
        Create a new blank document.

        Args:
            document_type: Type of document to create
            **properties: Properties to set

        Returns:
            Document: New document
        """
        return Document(document_type, **properties)

    def add(self, document: Union[Document, List[Document]], Update: bool = True) -> 'Database':
        """
        Add document(s) to the database.

        Args:
            document: Single document or list of documents
            Update: If True, update existing documents with same ID

        Returns:
            Database: Self for chaining
        """
        if not isinstance(document, list):
            document = [document]

        for doc in document:
            self._do_add(doc, Update=Update)

        return self

    def read(self, document_id: str) -> Optional[Document]:
        """
        Read a document from the database by ID.

        Args:
            document_id: Document ID to read

        Returns:
            Document or None: Document if found
        """
        return self._do_read(document_id)

    def remove(self, document_id: Union[str, Document, List]) -> 'Database':
        """
        Remove document(s) from the database.

        Args:
            document_id: Document ID, Document object, or list of either

        Returns:
            Database: Self for chaining
        """
        if not isinstance(document_id, list):
            document_id = [document_id]

        for doc_or_id in document_id:
            if isinstance(doc_or_id, Document):
                self._do_remove(doc_or_id.id())
            else:
                self._do_remove(doc_or_id)

        return self

    def search(self, query: Query) -> List[Document]:
        """
        Search for documents matching a query.

        Args:
            query: Query object

        Returns:
            List[Document]: List of matching documents
        """
        return self._do_search(query)

    def alldocids(self) -> List[str]:
        """
        Get all document IDs in the database.

        Returns:
            List[str]: List of document IDs
        """
        # Override in subclasses
        return []

    def clear(self, areyousure: str = 'no') -> None:
        """
        Clear all documents from the database.

        Args:
            areyousure: Must be 'yes' to proceed
        """
        if areyousure.lower() != 'yes':
            print("Not clearing because user did not indicate they are sure.")
            return

        for doc_id in self.alldocids():
            self.remove(doc_id)

    def openbinarydoc(self, document_or_id: Union[str, Document], filename: str):
        """
        Open a binary document for reading.

        Args:
            document_or_id: Document or document ID
            filename: Name of the binary file

        Returns:
            File handle
        """
        if isinstance(document_or_id, Document):
            document_id = document_or_id.id()
        else:
            document_id = document_or_id

        return self._do_openbinarydoc(document_id, filename)

    def existbinarydoc(self, document_or_id: Union[str, Document], filename: str) -> tuple:
        """
        Check if a binary document exists.

        Args:
            document_or_id: Document or document ID
            filename: Name of the binary file

        Returns:
            Tuple of (exists: bool, filepath: str)
        """
        if isinstance(document_or_id, Document):
            document_id = document_or_id.id()
        else:
            document_id = document_or_id

        return self._check_exist_binarydoc(document_id, filename)

    def closebinarydoc(self, binarydoc_obj):
        """
        Close a binary document.

        Args:
            binarydoc_obj: Binary document file handle

        Returns:
            Closed file handle
        """
        return self._do_closebinarydoc(binarydoc_obj)

    # Protected methods to be overridden in subclasses
    def _do_add(self, document: Document, Update: bool = True) -> None:
        """Override in subclass."""
        raise NotImplementedError()

    def _do_read(self, document_id: str) -> Optional[Document]:
        """Override in subclass."""
        raise NotImplementedError()

    def _do_remove(self, document_id: str) -> None:
        """Override in subclass."""
        raise NotImplementedError()

    def _do_search(self, query: Query) -> List[Document]:
        """Override in subclass."""
        raise NotImplementedError()

    def _do_openbinarydoc(self, document_id: str, filename: str):
        """Override in subclass."""
        raise NotImplementedError()

    def _check_exist_binarydoc(self, document_id: str, filename: str) -> tuple:
        """Override in subclass."""
        raise NotImplementedError()

    def _do_closebinarydoc(self, binarydoc_obj):
        """Override in subclass."""
        if binarydoc_obj:
            binarydoc_obj.close()
        return binarydoc_obj


class DirectoryDatabase(Database):
    """
    File system directory-based database implementation.

    Stores documents as JSON files in a directory structure.
    """

    def __init__(self, path: str, session_unique_reference: str = ''):
        """
        Create a directory-based database.

        Args:
            path: Directory path for the database
            session_unique_reference: Session reference
        """
        super().__init__(path, session_unique_reference)

        # Create database directory if it doesn't exist
        self.db_path = Path(path) / 'ndi_database'
        self.db_path.mkdir(parents=True, exist_ok=True)

        # Create subdirectories
        self.docs_path = self.db_path / 'documents'
        self.docs_path.mkdir(exist_ok=True)

        self.binary_path = self.db_path / 'binary'
        self.binary_path.mkdir(exist_ok=True)

    def _do_add(self, document: Document, Update: bool = True) -> None:
        """Add a document to the file system."""
        doc_id = document.id()
        doc_file = self.docs_path / f"{doc_id}.json"

        # Check if document exists
        if doc_file.exists() and not Update:
            raise ValueError(f"Document {doc_id} already exists and Update=False")

        # Write document JSON
        with open(doc_file, 'w') as f:
            json.dump(document.document_properties, f, indent=2)

        # Handle file ingestion if needed
        if 'files' in document.document_properties:
            self._ingest_files(document)

    def _do_read(self, document_id: str) -> Optional[Document]:
        """Read a document from the file system."""
        doc_file = self.docs_path / f"{document_id}.json"

        if not doc_file.exists():
            return None

        with open(doc_file, 'r') as f:
            properties = json.load(f)

        return Document(properties)

    def _do_remove(self, document_id: str) -> None:
        """Remove a document from the file system."""
        doc_file = self.docs_path / f"{document_id}.json"

        if doc_file.exists():
            doc_file.unlink()

        # Remove binary files
        doc_binary_dir = self.binary_path / document_id
        if doc_binary_dir.exists():
            shutil.rmtree(doc_binary_dir)

    def _do_search(self, query: Query) -> List[Document]:
        """Search documents in the file system."""
        results = []

        for doc_file in self.docs_path.glob('*.json'):
            try:
                with open(doc_file, 'r') as f:
                    properties = json.load(f)
                doc = Document(properties)

                if query.matches(doc):
                    results.append(doc)
            except Exception as e:
                print(f"Error reading {doc_file}: {e}")
                continue

        return results

    def alldocids(self) -> List[str]:
        """Get all document IDs."""
        ids = []
        for doc_file in self.docs_path.glob('*.json'):
            ids.append(doc_file.stem)  # Filename without .json
        return ids

    def _ingest_files(self, document: Document) -> None:
        """Ingest binary files referenced by the document."""
        if 'file_info' not in document.document_properties.get('files', {}):
            return

        doc_binary_dir = self.binary_path / document.id()
        doc_binary_dir.mkdir(exist_ok=True)

        for file_info in document.document_properties['files']['file_info']:
            for location in file_info['locations']:
                if not location.get('ingest', False):
                    continue

                source = location['location']
                if not os.path.exists(source):
                    print(f"Warning: Source file not found: {source}")
                    continue

                # Copy file to binary directory
                dest = doc_binary_dir / file_info['name']
                shutil.copy2(source, dest)

                # Update location to point to database
                location['location'] = str(dest)

                # Delete original if requested
                if location.get('delete_original', False):
                    try:
                        os.remove(source)
                    except Exception as e:
                        print(f"Warning: Could not delete original file {source}: {e}")

    def _do_openbinarydoc(self, document_id: str, filename: str):
        """Open a binary document file."""
        doc_binary_dir = self.binary_path / document_id
        filepath = doc_binary_dir / filename

        if not filepath.exists():
            raise FileNotFoundError(f"Binary file not found: {filepath}")

        return open(filepath, 'rb')

    def _check_exist_binarydoc(self, document_id: str, filename: str) -> tuple:
        """Check if a binary document exists."""
        doc_binary_dir = self.binary_path / document_id
        filepath = doc_binary_dir / filename

        return filepath.exists(), str(filepath)
