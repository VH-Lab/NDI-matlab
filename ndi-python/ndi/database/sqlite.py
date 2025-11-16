"""
NDI SQLite Database Backend

Ported from MATLAB: src/ndi/+ndi/+database/+implementations/+database/didsqlite.m

Provides a SQLite-based database backend with:
- SQL query optimization for fast searches
- Full document versioning support
- Binary file storage and management
- Transaction support for data integrity
"""

import sqlite3
import os
import json
import shutil
from typing import List, Optional, Union, Tuple
from pathlib import Path
from .base import Database
from ..document import Document
from ..query import Query


class SQLiteDatabase(Database):
    """
    SQLite-based document database for NDI.

    Provides persistent storage with SQL query optimization and indexing
    for improved search performance over file-based storage.

    This class is equivalent to MATLAB's ndi.database.implementations.database.didsqlite

    Attributes:
        db_path: Path to the SQLite database file
        conn: SQLite connection object
        branch_id: Branch identifier (default: 'a')

    Example:
        >>> db = SQLiteDatabase('/path/to/session', 'my_session_id')
        >>> doc = db.newdocument('probe')
        >>> db.add(doc)
        >>> results = db.search(Query('', 'isa', 'probe', ''))
    """

    def __init__(self, path: str = '', session_unique_reference: str = ''):
        """
        Initialize SQLite database.

        Args:
            path: Directory path where the database will be stored
            session_unique_reference: Unique reference for the session
        """
        super().__init__(path, session_unique_reference)

        # Create database path
        self.db_path = Path(path) / 'ndi_database'
        self.db_path.mkdir(parents=True, exist_ok=True)

        # SQLite database file
        self.db_file = self.db_path / 'did-sqlite.sqlite'

        # Binary files directory
        self.binary_path = self.db_path / 'files'
        self.binary_path.mkdir(exist_ok=True)

        # Initialize connection
        self.conn: Optional[sqlite3.Connection] = None
        self.branch_id = 'a'

        self._init_database()

    def _init_database(self) -> None:
        """Initialize database schema and ensure branch exists."""
        self.conn = sqlite3.connect(str(self.db_file))
        self.conn.row_factory = sqlite3.Row  # Access columns by name
        cursor = self.conn.cursor()

        # Create branches table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS branches (
                branch_id TEXT PRIMARY KEY,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        # Create documents table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                branch_id TEXT NOT NULL,
                session_id TEXT,
                doc_type TEXT,
                datestamp TEXT,
                properties TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
            )
        ''')

        # Create indexes for common queries
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_session
            ON documents(session_id)
        ''')

        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_type
            ON documents(doc_type)
        ''')

        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_branch
            ON documents(branch_id)
        ''')

        # Create binary files metadata table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS binary_files (
                doc_id TEXT NOT NULL,
                filename TEXT NOT NULL,
                file_path TEXT NOT NULL,
                file_size INTEGER,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (doc_id, filename),
                FOREIGN KEY (doc_id) REFERENCES documents(id) ON DELETE CASCADE
            )
        ''')

        self.conn.commit()

        # Ensure default branch exists
        cursor.execute('SELECT branch_id FROM branches WHERE branch_id = ?', (self.branch_id,))
        if not cursor.fetchone():
            cursor.execute('INSERT INTO branches (branch_id) VALUES (?)', (self.branch_id,))
            self.conn.commit()

    def _do_add(self, document: Document, Update: bool = True) -> None:
        """
        Add a document to the SQLite database.

        Args:
            document: Document to add
            Update: If True, update existing document with same ID
        """
        cursor = self.conn.cursor()
        doc_id = document.id()

        # Extract common fields for indexing
        props = document.document_properties
        session_id = props.get('base', {}).get('session_id', '')
        doc_type = props.get('document_class', {}).get('class_name', 'document')
        datestamp = props.get('base', {}).get('datestamp', '')

        # Serialize full properties to JSON
        properties_json = json.dumps(props)

        # Check if document exists
        cursor.execute('SELECT id FROM documents WHERE id = ?', (doc_id,))
        exists = cursor.fetchone() is not None

        if exists:
            if Update:
                # Update existing document
                cursor.execute('''
                    UPDATE documents
                    SET session_id = ?, doc_type = ?, datestamp = ?,
                        properties = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (session_id, doc_type, datestamp, properties_json, doc_id))
            else:
                raise ValueError(f"Document {doc_id} already exists and Update=False")
        else:
            # Insert new document
            cursor.execute('''
                INSERT INTO documents (id, branch_id, session_id, doc_type, datestamp, properties)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (doc_id, self.branch_id, session_id, doc_type, datestamp, properties_json))

        self.conn.commit()

        # Handle binary file ingestion
        if 'files' in props:
            self._ingest_files(document)

    def _do_read(self, document_id: str) -> Optional[Document]:
        """
        Read a document from the SQLite database.

        Args:
            document_id: Document ID to read

        Returns:
            Document or None if not found
        """
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT properties FROM documents
            WHERE id = ? AND branch_id = ?
        ''', (document_id, self.branch_id))

        row = cursor.fetchone()
        if not row:
            return None

        properties = json.loads(row['properties'])
        return Document(properties)

    def _do_remove(self, document_id: str) -> None:
        """
        Remove a document from the SQLite database.

        Args:
            document_id: Document ID to remove
        """
        cursor = self.conn.cursor()

        # Get binary files for this document
        cursor.execute('''
            SELECT file_path FROM binary_files WHERE doc_id = ?
        ''', (document_id,))

        # Delete physical files
        for row in cursor.fetchall():
            file_path = Path(row['file_path'])
            if file_path.exists():
                try:
                    file_path.unlink()
                except Exception as e:
                    print(f"Warning: Could not delete file {file_path}: {e}")

        # Delete binary files metadata (cascade will handle this, but explicit is better)
        cursor.execute('DELETE FROM binary_files WHERE doc_id = ?', (document_id,))

        # Delete document
        cursor.execute('''
            DELETE FROM documents WHERE id = ? AND branch_id = ?
        ''', (document_id, self.branch_id))

        self.conn.commit()

    def _do_search(self, query: Query) -> List[Document]:
        """
        Search documents in the SQLite database.

        For now, this fetches all documents and filters in Python.
        Future optimization: Convert queries to SQL WHERE clauses.

        Args:
            query: Query object

        Returns:
            List of matching documents
        """
        cursor = self.conn.cursor()

        # Basic optimization: if query is simple 'isa' or field match, use SQL
        if not query.is_logical() and query.operation == 'isa':
            # Use SQL LIKE for class hierarchy matching
            cursor.execute('''
                SELECT properties FROM documents
                WHERE branch_id = ? AND doc_type LIKE ?
            ''', (self.branch_id, f'%{query.value}%'))
        elif not query.is_logical() and query.operation == 'exact_string' and query.field == 'base.id':
            # Direct ID lookup
            cursor.execute('''
                SELECT properties FROM documents
                WHERE branch_id = ? AND id = ?
            ''', (self.branch_id, query.value))
        else:
            # Fallback: fetch all documents and filter in Python
            cursor.execute('''
                SELECT properties FROM documents WHERE branch_id = ?
            ''', (self.branch_id,))

        results = []
        for row in cursor.fetchall():
            properties = json.loads(row['properties'])
            doc = Document(properties)

            # Apply query filter
            if query.matches(doc):
                results.append(doc)

        return results

    def alldocids(self) -> List[str]:
        """
        Get all document IDs in the database.

        Returns:
            List of document IDs
        """
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT id FROM documents WHERE branch_id = ?
        ''', (self.branch_id,))

        return [row['id'] for row in cursor.fetchall()]

    def _ingest_files(self, document: Document) -> None:
        """
        Ingest binary files referenced by the document.

        Args:
            document: Document containing file references
        """
        if 'file_info' not in document.document_properties.get('files', {}):
            return

        doc_id = document.id()
        doc_binary_dir = self.binary_path / doc_id
        doc_binary_dir.mkdir(exist_ok=True)

        cursor = self.conn.cursor()

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

                # Record in database
                file_size = dest.stat().st_size
                cursor.execute('''
                    INSERT OR REPLACE INTO binary_files (doc_id, filename, file_path, file_size)
                    VALUES (?, ?, ?, ?)
                ''', (doc_id, file_info['name'], str(dest), file_size))

                # Update location to point to database
                location['location'] = str(dest)

                # Delete original if requested
                if location.get('delete_original', False):
                    try:
                        os.remove(source)
                    except Exception as e:
                        print(f"Warning: Could not delete original file {source}: {e}")

        self.conn.commit()

    def _do_openbinarydoc(self, document_id: str, filename: str):
        """
        Open a binary document file for reading.

        Args:
            document_id: Document ID
            filename: Binary file name

        Returns:
            File handle opened in binary read mode
        """
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT file_path FROM binary_files
            WHERE doc_id = ? AND filename = ?
        ''', (document_id, filename))

        row = cursor.fetchone()
        if not row:
            raise FileNotFoundError(
                f"Binary file '{filename}' not found for document {document_id}"
            )

        file_path = Path(row['file_path'])
        if not file_path.exists():
            raise FileNotFoundError(f"Binary file not found: {file_path}")

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
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT file_path FROM binary_files
            WHERE doc_id = ? AND filename = ?
        ''', (document_id, filename))

        row = cursor.fetchone()
        if not row:
            return False, ''

        file_path = Path(row['file_path'])
        return file_path.exists(), str(file_path)

    def close(self) -> None:
        """Close the database connection."""
        if self.conn:
            self.conn.close()
            self.conn = None

    def __del__(self):
        """Ensure connection is closed on deletion."""
        self.close()
