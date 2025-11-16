"""
Test suite for NDI database utility functions (Phase 2).

Tests the database utility functions in ndi.db.fun:
- extract_docs_files
- ndicloud_metadata
"""

import pytest
import tempfile
import os
from pathlib import Path

from ndi.database.sqlite import SQLiteDatabase
from ndi.document import Document
from ndi.query import Query
from ndi.db.fun import extract_docs_files, ndicloud_metadata


class MockSession:
    """Mock session object for testing database utilities."""

    def __init__(self, db):
        self.database = db
        self.reference = 'mock_session'

    def id(self):
        return 'mock_session_id_12345'

    def database_search(self, query):
        """Search documents in the database."""
        return self.database.search(query)

    def database_openbinarydoc(self, doc_id, filename):
        """Open a binary document."""
        return self.database.openbinarydoc(doc_id, filename)


class TestExtractDocsFiles:
    """Test suite for extract_docs_files function."""

    @pytest.fixture
    def session_with_docs(self, tmp_path):
        """Create a mock session with test documents."""
        db = SQLiteDatabase(str(tmp_path / 'db'), 'test_session')
        session = MockSession(db)

        # Add some documents
        for i in range(3):
            doc = db.newdocument('probe')
            doc.document_properties['base'] = {
                'id': doc.id(),
                'name': f'probe_{i}',
                'session_id': 'test_session'
            }
            db.add(doc)

        yield session
        db.close()

    def test_extract_docs_basic(self, session_with_docs, tmp_path):
        """Test basic document extraction."""
        target_path = str(tmp_path / 'extracted')

        docs, path = extract_docs_files(session_with_docs, target_path)

        # Should return documents
        assert len(docs) == 3
        assert all(isinstance(doc, Document) for doc in docs)

        # Target path should be created
        assert os.path.exists(path)
        assert path == target_path

    def test_extract_docs_auto_path(self, session_with_docs):
        """Test extraction with automatic path creation."""
        docs, path = extract_docs_files(session_with_docs)

        # Should return documents
        assert len(docs) == 3

        # Auto-generated path should exist
        assert os.path.exists(path)
        assert 'ndi_extract_' in path

    def test_extract_docs_invalid_session(self):
        """Test that invalid session raises TypeError."""
        with pytest.raises(TypeError):
            extract_docs_files("not a session")


class TestNDICloudMetadata:
    """Test suite for ndicloud_metadata function."""

    @pytest.fixture
    def session_with_docs(self, tmp_path):
        """Create a mock session with test documents."""
        db = SQLiteDatabase(str(tmp_path / 'db'), 'test_session')
        session = MockSession(db)

        # Add documents
        for i in range(3):
            doc = db.newdocument('probe')
            doc.document_properties['base'] = {
                'id': doc.id(),
                'name': f'probe_{i}',
                'session_id': 'test_session',
                'datestamp': f'2024-01-{i+1:02d}'
            }
            doc.document_properties['document_class'] = {
                'class_name': f'ndi.element.probe'
            }
            db.add(doc)

        yield session
        db.close()

    def test_ndicloud_metadata_basic(self, session_with_docs):
        """Test basic metadata extraction."""
        metadata = ndicloud_metadata(session_with_docs)

        # Check structure
        assert 'documents' in metadata
        assert 'files' in metadata
        assert 'session_info' in metadata
        assert 'stats' in metadata

        # Check document count
        assert len(metadata['documents']) == 3
        assert metadata['stats']['document_count'] == 3

        # Check session info
        assert metadata['session_info']['session_id'] == 'mock_session_id_12345'
        assert metadata['session_info']['reference'] == 'mock_session'

    def test_ndicloud_metadata_without_files(self, session_with_docs):
        """Test metadata extraction without file info."""
        metadata = ndicloud_metadata(session_with_docs, include_files=False)

        # Files list should be empty
        assert len(metadata['files']) == 0
        assert metadata['stats']['file_count'] == 0

    def test_ndicloud_metadata_document_info(self, session_with_docs):
        """Test that document metadata is correct."""
        metadata = ndicloud_metadata(session_with_docs)

        # Check first document
        doc_meta = metadata['documents'][0]
        assert 'id' in doc_meta
        assert 'type' in doc_meta
        assert 'datestamp' in doc_meta
        assert 'has_files' in doc_meta

        # Type should be probe
        assert doc_meta['type'] == 'ndi.element.probe'

    def test_ndicloud_metadata_invalid_session(self):
        """Test that invalid session raises TypeError."""
        with pytest.raises(TypeError):
            ndicloud_metadata("not a session")


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
