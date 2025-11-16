"""
NDI MATLABDumbJSONDB2 Database Backend

Ported from MATLAB: src/ndi/+ndi/+database/+implementations/+database/matlabdumbjsondb2.m

Provides an enhanced JSON file-based database backend with:
- Human-readable JSON document storage
- Full binary file ingestion and management
- File lifecycle management (copy, delete on remove)
- Improved file organization

This is an enhanced version of MATLABDumbJSONDB with proper
binary file handling, suitable for medium-sized datasets.
"""

import os
import json
import shutil
from typing import List, Optional, Union, Tuple
from pathlib import Path
from .matlabdumbjsondb import MATLABDumbJSONDB
from ..document import Document


class MATLABDumbJSONDB2(MATLABDumbJSONDB):
    """
    Enhanced JSON file-based document database with file management.

    Extends MATLABDumbJSONDB with full binary file ingestion and lifecycle
    management. Files referenced in documents are copied into the database
    and managed throughout the document lifecycle.

    This class is equivalent to MATLAB's:
    ndi.database.implementations.database.matlabdumbjsondb2

    Attributes:
        db_path: Path to the database directory
        docs_path: Path to the documents directory
        binary_path: Path to the binary files directory
        index_file: Path to the document index file

    Example:
        >>> db = MATLABDumbJSONDB2('/path/to/session', 'my_session_id')
        >>> doc = db.newdocument('probe')
        >>> doc.add_file('data.bin', '/path/to/data.bin')
        >>> db.add(doc)
        >>> fh = db.openbinarydoc(doc, 'data.bin')

    Notes:
        - Inherits simple JSON storage from MATLABDumbJSONDB
        - Adds binary file ingestion during document add
        - Manages file deletion during document removal
        - Organizes binary files in a separate 'files' directory
    """

    def __init__(self, path: str = '', session_unique_reference: str = ''):
        """
        Initialize MATLABDumbJSONDB2 database.

        Args:
            path: Directory path where the database will be stored
            session_unique_reference: Unique reference for the session
        """
        super().__init__(path, session_unique_reference)

        # Binary files directory (relative to db root, not dumbjsondb subdir)
        db_root = Path(path) / 'ndi_database'
        self.binary_path = db_root / 'files'
        self.binary_path.mkdir(exist_ok=True)

    def _ingest_plan(self, document: Document) -> Tuple[List[str], List[str], List[str]]:
        """
        Plan file ingestion for a document.

        Analyzes document file references and creates a plan for:
        - Which files to copy (source paths)
        - Where to copy them (destination paths)
        - Which original files to delete after copying

        Args:
            document: Document with file references

        Returns:
            Tuple of (source_files, dest_files, to_delete_files)
        """
        source_files = []
        dest_files = []
        to_delete_files = []

        if 'files' not in document.document_properties:
            return source_files, dest_files, to_delete_files

        file_info_list = document.document_properties['files'].get('file_info', [])
        if not file_info_list:
            return source_files, dest_files, to_delete_files

        for file_info in file_info_list:
            locations = file_info.get('locations', [])
            filename = file_info.get('name', '')

            for location in locations:
                if not location.get('ingest', False):
                    continue

                source = location.get('location', '')
                if not source or not os.path.exists(source):
                    continue

                # Determine destination filename
                dest = self.binary_path / filename
                source_files.append(source)
                dest_files.append(str(dest))

                # Check if we should delete original
                if location.get('delete_original', False):
                    to_delete_files.append(source)

        return source_files, dest_files, to_delete_files

    def _ingest(self, source_files: List[str], dest_files: List[str],
                to_delete_files: List[str]) -> Tuple[bool, str]:
        """
        Execute file ingestion plan.

        Copies files from source to destination and optionally deletes originals.

        Args:
            source_files: List of source file paths
            dest_files: List of destination file paths
            to_delete_files: List of files to delete after copying

        Returns:
            Tuple of (success: bool, message: str)
        """
        try:
            # Copy files
            for source, dest in zip(source_files, dest_files):
                dest_path = Path(dest)
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, dest)

            # Delete originals if requested
            for file_path in to_delete_files:
                try:
                    if os.path.exists(file_path):
                        os.remove(file_path)
                except Exception as e:
                    print(f"Warning: Could not delete {file_path}: {e}")

            return True, "Ingestion successful"

        except Exception as e:
            return False, f"Ingestion failed: {e}"

    def _expell_plan(self, document: Document) -> List[str]:
        """
        Plan file deletion for document removal.

        Determines which ingested files should be deleted when a document
        is removed from the database.

        Args:
            document: Document being removed

        Returns:
            List of file paths to delete
        """
        to_delete = []

        if 'files' not in document.document_properties:
            return to_delete

        file_info_list = document.document_properties['files'].get('file_info', [])
        if not file_info_list:
            return to_delete

        for file_info in file_info_list:
            filename = file_info.get('name', '')
            if filename:
                file_path = self.binary_path / filename
                if file_path.exists():
                    to_delete.append(str(file_path))

        return to_delete

    def _expell(self, to_delete_files: List[str]) -> Tuple[bool, str]:
        """
        Execute file deletion plan.

        Deletes files that were ingested for a removed document.

        Args:
            to_delete_files: List of file paths to delete

        Returns:
            Tuple of (success: bool, message: str)
        """
        try:
            for file_path in to_delete_files:
                if os.path.exists(file_path):
                    os.remove(file_path)

            return True, "Expulsion successful"

        except Exception as e:
            return False, f"Expulsion failed: {e}"

    def _do_add(self, document: Document, Update: bool = True) -> None:
        """
        Add a document to the database with file ingestion.

        Args:
            document: Document to add
            Update: If True, overwrite existing document (default: True)
        """
        # Plan file ingestion
        source_files, dest_files, to_delete_files = self._ingest_plan(document)

        # Update file locations in document to point to ingested paths
        if 'files' in document.document_properties:
            file_info_list = document.document_properties['files'].get('file_info', [])
            for file_info, dest in zip(file_info_list, dest_files):
                for location in file_info.get('locations', []):
                    if location.get('ingest', False):
                        location['location'] = dest

        # Add document using parent class method
        super()._do_add(document, Update=Update)

        # Ingest files after document is saved
        success, msg = self._ingest(source_files, dest_files, to_delete_files)
        if not success:
            print(f"Warning: File ingestion had issues: {msg}")

    def _do_remove(self, document_id: str) -> None:
        """
        Remove a document from the database and delete its files.

        Args:
            document_id: Document ID to remove
        """
        # Read document to get file information
        doc = self._do_read(document_id)

        # Plan file deletion
        if doc:
            to_delete = self._expell_plan(doc)
        else:
            to_delete = []

        # Remove document using parent class method
        super()._do_remove(document_id)

        # Delete ingested files
        if to_delete:
            success, msg = self._expell(to_delete)
            if not success:
                print(f"Warning: File deletion had issues: {msg}")

    def _doc2ingesteddbfilename(self, document: Document, filename: str) -> str:
        """
        Get the ingested database filename for a file referenced in a document.

        In this simple implementation, the ingested filename is just the original
        filename. More complex schemes could use document IDs or hashing.

        Args:
            document: Document containing file reference
            filename: Original filename

        Returns:
            Ingested filename (in this case, same as original)
        """
        # Simple implementation: use original filename
        # Could be enhanced with: f"{document.id()}_{filename}"
        return filename

    def _do_openbinarydoc(self, document_id: str, filename: str):
        """
        Open a binary document file for reading.

        Args:
            document_id: Document ID
            filename: Binary file name

        Returns:
            File handle opened in binary read mode
        """
        # Read document to get actual ingested filename
        doc = self._do_read(document_id)
        if not doc:
            raise FileNotFoundError(f"Document {document_id} not found")

        # Get ingested filename
        ingested_filename = self._doc2ingesteddbfilename(doc, filename)
        file_path = self.binary_path / ingested_filename

        if not file_path.exists():
            raise FileNotFoundError(
                f"Binary file '{filename}' not found for document {document_id} "
                f"(expected at: {file_path})"
            )

        return open(file_path, 'rb')

    def _check_exist_binarydoc(self, document_id: str, filename: str) -> Tuple[bool, str]:
        """
        Check if a binary document exists.

        Args:
            document_id: Document ID
            filename: Binary file name

        Returns:
            Tuple of (exists: bool, file_path: str)
        """
        try:
            # Read document to get actual ingested filename
            doc = self._do_read(document_id)
            if not doc:
                return False, ''

            # Get ingested filename
            ingested_filename = self._doc2ingesteddbfilename(doc, filename)
            file_path = self.binary_path / ingested_filename

            if file_path.exists():
                return True, str(file_path)
            else:
                return False, ''

        except Exception:
            return False, ''

    def file_directory(self) -> str:
        """
        Get the directory where binary files are stored.

        Returns:
            Path to the binary files directory
        """
        return str(self.binary_path)
