"""
Tests for ndi.Session
"""

import pytest
import tempfile
import shutil
from pathlib import Path
from ndi import SessionDir, Document, Query


class TestSession:
    """Test suite for Session class."""

    @pytest.fixture
    def temp_session_dir(self):
        """Create a temporary directory for session testing."""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    def test_session_creation(self, temp_session_dir):
        """Test creating a session."""
        session = SessionDir(temp_session_dir, 'test_session')
        assert session.reference == 'test_session'
        assert len(session.id()) == 32
        assert session.database is not None

    def test_session_id(self, temp_session_dir):
        """Test session ID method."""
        session = SessionDir(temp_session_dir, 'test_session')
        session_id = session.id()
        assert isinstance(session_id, str)
        assert len(session_id) == 32

    def test_newdocument(self, temp_session_dir):
        """Test creating a new document."""
        session = SessionDir(temp_session_dir, 'test_session')
        doc = session.newdocument('base', **{'base.name': 'test_doc'})

        assert doc.session_id() == session.id()
        assert doc.document_properties['base']['name'] == 'test_doc'

    def test_database_add_and_search(self, temp_session_dir):
        """Test adding and searching documents."""
        session = SessionDir(temp_session_dir, 'test_session')

        # Create and add document
        doc = session.newdocument('base', **{'base.name': 'probe1'})
        session.database_add(doc)

        # Search for it
        q = Query('base.name', 'exact_string', 'probe1')
        results = session.database_search(q)

        assert len(results) == 1
        assert results[0].document_properties['base']['name'] == 'probe1'

    def test_database_remove(self, temp_session_dir):
        """Test removing documents."""
        session = SessionDir(temp_session_dir, 'test_session')

        # Add document
        doc = session.newdocument('base', **{'base.name': 'probe1'})
        session.database_add(doc)

        # Remove it
        session.database_rm(doc)

        # Should not find it
        q = Query('base.name', 'exact_string', 'probe1')
        results = session.database_search(q)
        assert len(results) == 0

    def test_searchquery(self, temp_session_dir):
        """Test session search query."""
        session = SessionDir(temp_session_dir, 'test_session')
        q = session.searchquery()

        assert q.field == 'base.session_id'
        assert q.value == session.id()

    def test_session_equality(self, temp_session_dir):
        """Test session equality."""
        session1 = SessionDir(temp_session_dir, 'session1')
        session2 = SessionDir(temp_session_dir, 'session2')

        # Different sessions
        assert session1 != session2

        # Same session
        assert session1 == session1

    def test_multiple_documents(self, temp_session_dir):
        """Test adding multiple documents."""
        session = SessionDir(temp_session_dir, 'test_session')

        # Add multiple documents
        doc1 = session.newdocument('base', **{'base.name': 'probe1'})
        doc2 = session.newdocument('base', **{'base.name': 'probe2'})
        doc3 = session.newdocument('base', **{'base.name': 'probe3'})

        session.database_add([doc1, doc2, doc3])

        # Search for all
        q = session.searchquery()
        results = session.database_search(q)

        assert len(results) == 3


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
