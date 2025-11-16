"""
Test suite for NDI database backends (Phase 2).

Tests all three database backend implementations:
- SQLiteDatabase
- MATLABDumbJSONDB
- MATLABDumbJSONDB2
"""

import pytest
import tempfile
import shutil
from pathlib import Path
import json

from ndi.database.sqlite import SQLiteDatabase
from ndi.database.matlabdumbjsondb import MATLABDumbJSONDB
from ndi.database.matlabdumbjsondb2 import MATLABDumbJSONDB2
from ndi.document import Document
from ndi.query import Query


class TestDatabaseBackends:
    """Test suite for all database backends."""

    @pytest.fixture(params=[SQLiteDatabase, MATLABDumbJSONDB, MATLABDumbJSONDB2])
    def db_backend(self, request, tmp_path):
        """
        Parametrized fixture that creates each database backend.

        This ensures all tests run on all three backends.
        """
        db_class = request.param
        db = db_class(str(tmp_path), 'test_session_id')
        yield db

        # Cleanup
        if hasattr(db, 'close'):
            db.close()

    def test_database_initialization(self, db_backend):
        """Test that database initializes correctly."""
        assert db_backend is not None
        assert db_backend.path
        assert db_backend.session_unique_reference == 'test_session_id'

    def test_newdocument(self, db_backend):
        """Test creating a new blank document."""
        doc = db_backend.newdocument('probe')
        assert doc is not None
        assert isinstance(doc, Document)

    def test_add_and_read_document(self, db_backend):
        """Test adding and reading a document."""
        # Create a document
        doc = db_backend.newdocument('probe')
        doc.document_properties['base'] = {
            'id': doc.id(),
            'name': 'test_probe',
            'session_id': 'test_session_id'
        }

        # Add to database
        db_backend.add(doc)

        # Read back
        doc_read = db_backend.read(doc.id())
        assert doc_read is not None
        assert doc_read.id() == doc.id()
        assert doc_read.document_properties['base']['name'] == 'test_probe'

    def test_add_update_document(self, db_backend):
        """Test updating an existing document."""
        # Create and add document
        doc = db_backend.newdocument('probe')
        doc.document_properties['base'] = {
            'id': doc.id(),
            'name': 'original_name',
            'session_id': 'test_session_id'
        }
        db_backend.add(doc)

        # Update document
        doc.document_properties['base']['name'] = 'updated_name'
        db_backend.add(doc, Update=True)

        # Verify update
        doc_read = db_backend.read(doc.id())
        assert doc_read.document_properties['base']['name'] == 'updated_name'

    def test_add_no_update_raises(self, db_backend):
        """Test that adding duplicate with Update=False raises error."""
        doc = db_backend.newdocument('probe')
        doc.document_properties['base'] = {
            'id': doc.id(),
            'name': 'test_probe',
            'session_id': 'test_session_id'
        }

        # Add first time
        db_backend.add(doc)

        # Try to add again with Update=False
        with pytest.raises(ValueError):
            db_backend.add(doc, Update=False)

    def test_remove_document(self, db_backend):
        """Test removing a document."""
        # Create and add document
        doc = db_backend.newdocument('probe')
        doc.document_properties['base'] = {
            'id': doc.id(),
            'name': 'test_probe',
            'session_id': 'test_session_id'
        }
        db_backend.add(doc)

        # Verify it exists
        assert db_backend.read(doc.id()) is not None

        # Remove it
        db_backend.remove(doc.id())

        # Verify it's gone
        assert db_backend.read(doc.id()) is None

    def test_search_exact_string(self, db_backend):
        """Test searching with exact string match."""
        # Add multiple documents
        for i in range(3):
            doc = db_backend.newdocument('probe')
            doc.document_properties['base'] = {
                'id': doc.id(),
                'name': f'probe_{i}',
                'session_id': 'test_session_id'
            }
            db_backend.add(doc)

        # Search for specific name
        q = Query('base.name', 'exact_string', 'probe_1', '')
        results = db_backend.search(q)

        assert len(results) == 1
        assert results[0].document_properties['base']['name'] == 'probe_1'

    def test_search_isa(self, db_backend):
        """Test searching with 'isa' query."""
        # Add documents of different types
        doc1 = db_backend.newdocument('probe')
        doc1.document_properties['base'] = {'id': doc1.id(), 'session_id': 'test_session_id'}
        doc1.document_properties['document_class'] = {'class_name': 'ndi.element.probe'}
        db_backend.add(doc1)

        doc2 = db_backend.newdocument('element')
        doc2.document_properties['base'] = {'id': doc2.id(), 'session_id': 'test_session_id'}
        doc2.document_properties['document_class'] = {'class_name': 'ndi.element'}
        db_backend.add(doc2)

        # Search for probe
        q = Query('', 'isa', 'probe', '')
        results = db_backend.search(q)

        # Should find at least doc1
        assert len(results) >= 1
        found_ids = [doc.id() for doc in results]
        assert doc1.id() in found_ids

    def test_search_and_query(self, db_backend):
        """Test searching with AND query combination."""
        # Add documents
        doc1 = db_backend.newdocument('probe')
        doc1.document_properties['base'] = {
            'id': doc1.id(),
            'name': 'probe_A',
            'session_id': 'test_session_id',
            'type': 'electrode'
        }
        db_backend.add(doc1)

        doc2 = db_backend.newdocument('probe')
        doc2.document_properties['base'] = {
            'id': doc2.id(),
            'name': 'probe_B',
            'session_id': 'test_session_id',
            'type': 'optical'
        }
        db_backend.add(doc2)

        # Search with AND query
        q1 = Query('base.name', 'exact_string', 'probe_A', '')
        q2 = Query('base.type', 'exact_string', 'electrode', '')
        q = q1 & q2

        results = db_backend.search(q)
        assert len(results) == 1
        assert results[0].id() == doc1.id()

    def test_search_or_query(self, db_backend):
        """Test searching with OR query combination."""
        # Add documents
        doc1 = db_backend.newdocument('probe')
        doc1.document_properties['base'] = {
            'id': doc1.id(),
            'name': 'probe_A',
            'session_id': 'test_session_id'
        }
        db_backend.add(doc1)

        doc2 = db_backend.newdocument('probe')
        doc2.document_properties['base'] = {
            'id': doc2.id(),
            'name': 'probe_B',
            'session_id': 'test_session_id'
        }
        db_backend.add(doc2)

        # Search with OR query
        q1 = Query('base.name', 'exact_string', 'probe_A', '')
        q2 = Query('base.name', 'exact_string', 'probe_B', '')
        q = q1 | q2

        results = db_backend.search(q)
        assert len(results) == 2

    def test_alldocids(self, db_backend):
        """Test getting all document IDs."""
        # Initially empty
        assert len(db_backend.alldocids()) == 0

        # Add documents
        doc_ids = []
        for i in range(3):
            doc = db_backend.newdocument('probe')
            doc.document_properties['base'] = {
                'id': doc.id(),
                'session_id': 'test_session_id'
            }
            db_backend.add(doc)
            doc_ids.append(doc.id())

        # Check all IDs are returned
        all_ids = db_backend.alldocids()
        assert len(all_ids) == 3
        for doc_id in doc_ids:
            assert doc_id in all_ids

    def test_clear_database(self, db_backend):
        """Test clearing all documents."""
        # Add documents
        for i in range(3):
            doc = db_backend.newdocument('probe')
            doc.document_properties['base'] = {
                'id': doc.id(),
                'session_id': 'test_session_id'
            }
            db_backend.add(doc)

        # Verify documents exist
        assert len(db_backend.alldocids()) == 3

        # Clear database
        db_backend.clear('yes')

        # Verify empty
        assert len(db_backend.alldocids()) == 0

    def test_clear_database_safety(self, db_backend):
        """Test that clear requires 'yes' confirmation."""
        # Add a document
        doc = db_backend.newdocument('probe')
        doc.document_properties['base'] = {
            'id': doc.id(),
            'session_id': 'test_session_id'
        }
        db_backend.add(doc)

        # Try to clear with 'no' (default)
        db_backend.clear('no')

        # Document should still exist
        assert len(db_backend.alldocids()) == 1


class TestSQLiteSpecific:
    """Tests specific to SQLite backend."""

    @pytest.fixture
    def sqlite_db(self, tmp_path):
        """Create SQLite database for testing."""
        db = SQLiteDatabase(str(tmp_path), 'test_session_id')
        yield db
        db.close()

    def test_sqlite_file_created(self, sqlite_db):
        """Test that SQLite database file is created."""
        db_file = Path(sqlite_db.path) / 'ndi_database' / 'did-sqlite.sqlite'
        assert db_file.exists()

    def test_sqlite_connection(self, sqlite_db):
        """Test that SQLite connection is active."""
        assert sqlite_db.conn is not None

    def test_sqlite_branch_id(self, sqlite_db):
        """Test that default branch is created."""
        cursor = sqlite_db.conn.cursor()
        cursor.execute('SELECT branch_id FROM branches WHERE branch_id = ?',
                      (sqlite_db.branch_id,))
        assert cursor.fetchone() is not None


class TestMATLABDumbJSONDB2Specific:
    """Tests specific to MATLABDumbJSONDB2 (file management)."""

    @pytest.fixture
    def jsondb2(self, tmp_path):
        """Create MATLABDumbJSONDB2 for testing."""
        return MATLABDumbJSONDB2(str(tmp_path), 'test_session_id')

    def test_file_directory_created(self, jsondb2):
        """Test that file directory is created."""
        assert jsondb2.binary_path.exists()

    def test_file_directory_method(self, jsondb2):
        """Test file_directory() method."""
        file_dir = jsondb2.file_directory()
        assert file_dir
        assert Path(file_dir).exists()


class TestBinaryFileOperations:
    """Test binary file operations (only for backends that support it)."""

    @pytest.fixture(params=[SQLiteDatabase, MATLABDumbJSONDB2])
    def db_with_files(self, request, tmp_path):
        """
        Create database backend that supports binary files.

        Note: MATLABDumbJSONDB (basic version) doesn't support binary files.
        """
        db_class = request.param
        db = db_class(str(tmp_path), 'test_session_id')
        yield db
        if hasattr(db, 'close'):
            db.close()

    def test_binary_file_not_exist(self, db_with_files):
        """Test checking for non-existent binary file."""
        doc = db_with_files.newdocument('probe')
        doc.document_properties['base'] = {
            'id': doc.id(),
            'session_id': 'test_session_id'
        }
        db_with_files.add(doc)

        exists, path = db_with_files.existbinarydoc(doc.id(), 'nonexistent.bin')
        assert not exists
        assert path == ''


def test_matlabdumbjsondb_no_binary_support(tmp_path):
    """Test that basic MATLABDumbJSONDB raises error for binary files."""
    db = MATLABDumbJSONDB(str(tmp_path), 'test_session_id')

    doc = db.newdocument('probe')
    doc.document_properties['base'] = {
        'id': doc.id(),
        'session_id': 'test_session_id'
    }
    db.add(doc)

    # Should raise NotImplementedError
    with pytest.raises(NotImplementedError):
        db.openbinarydoc(doc.id(), 'test.bin')


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
