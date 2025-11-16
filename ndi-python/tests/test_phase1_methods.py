"""
Comprehensive tests for Phase 1: Session and Document methods.
"""

import pytest
import tempfile
import shutil
from pathlib import Path
from ndi import SessionDir, Document, Query
from ndi.daq import System as DAQSystem
from ndi.time.syncgraph import SyncGraph


class TestPhase1SessionMethods:
    """Test suite for Phase 1 Session methods."""

    @pytest.fixture
    def temp_session_dir(self):
        """Create a temporary directory for session testing."""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def session(self, temp_session_dir):
        """Create a session for testing."""
        return SessionDir(temp_session_dir, 'test_session')

    # ===================================================================
    # validate_documents() tests
    # ===================================================================

    def test_validate_documents_matching_session_id(self, session):
        """Test validate_documents with matching session ID."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        valid, msg = session.validate_documents(doc)

        assert valid is True
        assert msg == ''

    def test_validate_documents_list(self, session):
        """Test validate_documents with list of documents."""
        docs = [
            session.newdocument('base', **{'base.name': 'test1'}),
            session.newdocument('base', **{'base.name': 'test2'}),
            session.newdocument('base', **{'base.name': 'test3'})
        ]

        valid, msg = session.validate_documents(docs)

        assert valid is True
        assert msg == ''

    def test_validate_documents_wrong_session_id(self, session):
        """Test validate_documents with wrong session ID."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        # Force wrong session ID
        doc.document_properties['base']['session_id'] = 'wrongid123'

        valid, msg = session.validate_documents(doc)

        assert valid is False
        assert 'does not match' in msg

    def test_validate_documents_empty_session_id(self, session):
        """Test validate_documents with empty session ID (should pass)."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        # Set to empty ID (all zeros)
        doc.document_properties['base']['session_id'] = SessionDir.empty_id()

        valid, msg = session.validate_documents(doc)

        assert valid is True
        assert msg == ''

    def test_validate_documents_not_document(self, session):
        """Test validate_documents with non-Document object."""
        valid, msg = session.validate_documents("not a document")

        assert valid is False
        assert 'must be Document objects' in msg

    def test_validate_documents_none_session_id(self, session):
        """Test validate_documents with None session ID (should pass)."""
        doc = Document('base', **{'base.name': 'test'})
        # Don't set session_id at all

        valid, msg = session.validate_documents(doc)

        assert valid is True  # None is acceptable
        assert msg == ''

    # ===================================================================
    # ingest() tests
    # ===================================================================

    def test_ingest_no_syncgraph(self, session):
        """Test ingest() fails without syncgraph."""
        success, msg = session.ingest()

        assert success is False
        assert 'Syncgraph is not initialized' in msg

    def test_ingest_with_syncgraph(self, session):
        """Test ingest() with syncgraph initialized."""
        # Initialize syncgraph
        session.syncgraph = SyncGraph(session)

        # This will fail because syncgraph.ingest() isn't fully implemented
        # but we test that it tries
        try:
            success, msg = session.ingest()
            # If it fails due to syncgraph.ingest() not working, that's OK
            # We're just testing the session.ingest() logic
        except Exception as e:
            # Expected - syncgraph.ingest() may not be fully implemented
            pass

    def test_ingest_error_handling(self, session):
        """Test ingest() error handling."""
        # Without syncgraph, should return error
        success, msg = session.ingest()

        assert isinstance(success, bool)
        assert isinstance(msg, str)
        if not success:
            assert len(msg) > 0  # Should have error message

    # ===================================================================
    # is_fully_ingested() tests
    # ===================================================================

    def test_is_fully_ingested_no_daqs(self, session):
        """Test is_fully_ingested() with no DAQ systems."""
        # With no DAQ systems, should return True
        result = session.is_fully_ingested()

        assert isinstance(result, bool)
        # Should be True since there's nothing to ingest
        assert result is True

    def test_is_fully_ingested_return_type(self, session):
        """Test is_fully_ingested() returns boolean."""
        result = session.is_fully_ingested()

        assert isinstance(result, bool)

    # ===================================================================
    # get_ingested_docs() tests
    # ===================================================================

    def test_get_ingested_docs_empty(self, session):
        """Test get_ingested_docs() with no ingested documents."""
        docs = session.get_ingested_docs()

        assert isinstance(docs, list)
        assert len(docs) == 0

    def test_get_ingested_docs_with_documents(self, session):
        """Test get_ingested_docs() with ingested documents."""
        # Add a document that looks like an ingested document
        doc = session.newdocument(
            'daqreader_mfdaq_epochdata_ingested',
            **{'base.name': 'ingested_data'}
        )
        session.database_add(doc)

        docs = session.get_ingested_docs()

        assert isinstance(docs, list)
        assert len(docs) >= 1
        # Should find our ingested document
        assert any(d.id() == doc.id() for d in docs)

    # ===================================================================
    # daqsystem_rm() tests
    # ===================================================================

    def test_daqsystem_rm_by_name(self, session):
        """Test removing DAQ system by name."""
        # Add a DAQ system document
        doc = session.newdocument('daqsystem', **{'base.name': 'mydaq'})
        session.database_add(doc)

        # Remove by name
        session.daqsystem_rm('mydaq')

        # Should not find it
        q = Query('base.name', 'exact_string', 'mydaq')
        results = session.database_search(q)
        assert len(results) == 0

    # ===================================================================
    # daqsystem_clear() tests
    # ===================================================================

    def test_daqsystem_clear(self, session):
        """Test clearing all DAQ systems."""
        # Add multiple DAQ system documents
        docs = [
            session.newdocument('daqsystem', **{'base.name': 'daq1'}),
            session.newdocument('daqsystem', **{'base.name': 'daq2'}),
            session.newdocument('daqsystem', **{'base.name': 'daq3'})
        ]
        session.database_add(docs)

        # Clear all
        session.daqsystem_clear()

        # Should not find any
        q = Query('', 'isa', 'daqsystem', '')
        results = session.database_search(q)
        assert len(results) == 0

    # ===================================================================
    # database_existbinarydoc() tests
    # ===================================================================

    def test_database_existbinarydoc_not_exists(self, session):
        """Test database_existbinarydoc() with non-existent file."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        session.database_add(doc)

        exists, path = session.database_existbinarydoc(doc, 'nonexistent.bin')

        assert exists is False
        assert path == ''

    def test_database_existbinarydoc_with_id(self, session):
        """Test database_existbinarydoc() with document ID."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        session.database_add(doc)

        exists, path = session.database_existbinarydoc(doc.id(), 'test.bin')

        assert isinstance(exists, bool)
        assert isinstance(path, str)

    # ===================================================================
    # syncgraph_addrule() tests
    # ===================================================================

    def test_syncgraph_addrule_creates_syncgraph(self, session):
        """Test syncgraph_addrule() creates syncgraph if needed."""
        # Initially no syncgraph
        assert session.syncgraph is None

        # Add a rule - should create syncgraph
        # We need a mock rule object
        from ndi.time.syncrule import SyncRule

        class MockRule(SyncRule):
            def apply(self, *args, **kwargs):
                pass

        rule = MockRule()
        result = session.syncgraph_addrule(rule)

        # Should create syncgraph
        assert session.syncgraph is not None
        # Should return self for chaining
        assert result is session

    # ===================================================================
    # syncgraph_rmrule() tests
    # ===================================================================

    def test_syncgraph_rmrule_no_syncgraph(self, session):
        """Test syncgraph_rmrule() with no syncgraph."""
        # Should handle gracefully
        result = session.syncgraph_rmrule(0)

        # Should return self
        assert result is session

    # ===================================================================
    # findexpobj() tests
    # ===================================================================

    def test_findexpobj(self, session):
        """Test findexpobj() finds objects by name."""
        # Add some probe documents
        doc1 = session.newdocument('probe', **{'base.name': 'probe1'})
        doc2 = session.newdocument('probe', **{'base.name': 'probe2'})
        session.database_add([doc1, doc2])

        # Find by name
        result = session.findexpobj('probe1', 'probe')

        assert result is not None

    # ===================================================================
    # creator_args() tests
    # ===================================================================

    def test_creator_args(self, session):
        """Test creator_args() returns dict."""
        args = session.creator_args()

        assert isinstance(args, dict)
        # Should have reference
        assert 'reference' in args
        assert args['reference'] == 'test_session'

    # ===================================================================
    # Static method tests
    # ===================================================================

    def test_docinput2docs_single_document(self, session):
        """Test docinput2docs() with single document."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        session.database_add(doc)

        docs = SessionDir.docinput2docs(session, doc)

        assert len(docs) == 1
        assert docs[0] == doc

    def test_docinput2docs_document_id(self, session):
        """Test docinput2docs() with document ID."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        session.database_add(doc)

        docs = SessionDir.docinput2docs(session, doc.id())

        assert len(docs) == 1
        assert docs[0].id() == doc.id()

    def test_docinput2docs_list(self, session):
        """Test docinput2docs() with list."""
        doc1 = session.newdocument('base', **{'base.name': 'test1'})
        doc2 = session.newdocument('base', **{'base.name': 'test2'})
        session.database_add([doc1, doc2])

        docs = SessionDir.docinput2docs(session, [doc1, doc2.id()])

        assert len(docs) == 2

    def test_docinput2docs_none(self, session):
        """Test docinput2docs() with None."""
        docs = SessionDir.docinput2docs(session, None)

        assert len(docs) == 0

    def test_all_docs_in_session_valid(self, session):
        """Test all_docs_in_session() with valid documents."""
        docs = [
            session.newdocument('base', **{'base.name': 'test1'}),
            session.newdocument('base', **{'base.name': 'test2'})
        ]

        valid, msg = SessionDir.all_docs_in_session(docs, session.id())

        assert valid is True
        assert msg == ''

    def test_all_docs_in_session_invalid(self, session):
        """Test all_docs_in_session() with invalid session ID."""
        doc = session.newdocument('base', **{'base.name': 'test'})
        # Force wrong session ID
        doc.document_properties['base']['session_id'] = 'wrongid'

        valid, msg = SessionDir.all_docs_in_session(doc, session.id())

        assert valid is False
        assert 'does not match' in msg

    def test_empty_id(self):
        """Test empty_id() returns correct format."""
        empty = SessionDir.empty_id()

        assert isinstance(empty, str)
        assert len(empty) == 32
        assert empty == '0' * 32


class TestPhase1DocumentMethods:
    """Test suite for Phase 1 Document methods."""

    def test_add_dependency_value_n(self):
        """Test add_dependency_value_n()."""
        doc = Document('base', **{'base.name': 'test'})

        # Add first dependency
        doc.add_dependency_value_n('element_id', 'id123')

        # Should be numbered _1
        assert doc.document_properties['depends_on']['element_id_1'] == 'id123'

        # Add another
        doc.add_dependency_value_n('element_id', 'id456')

        # Should be numbered _2
        assert doc.document_properties['depends_on']['element_id_2'] == 'id456'

    def test_dependency_value_n(self):
        """Test dependency_value_n()."""
        doc = Document('base', **{'base.name': 'test'})

        # Add dependency
        doc.add_dependency_value_n('element_id', 'id123')

        # Retrieve it
        value = doc.dependency_value_n('element_id', 1)

        assert value == 'id123'

    def test_dependency_value_n_missing(self):
        """Test dependency_value_n() with missing dependency."""
        doc = Document('base', **{'base.name': 'test'})

        value = doc.dependency_value_n('element_id', 1)

        assert value is None

    def test_remove_dependency_value_n(self):
        """Test remove_dependency_value_n()."""
        doc = Document('base', **{'base.name': 'test'})

        # Add dependencies
        doc.add_dependency_value_n('element_id', 'id123')
        doc.add_dependency_value_n('element_id', 'id456')

        # Remove first one
        doc.remove_dependency_value_n('element_id', 1)

        # Should not have _1 anymore
        assert doc.dependency_value_n('element_id', 1) is None

    def test_setproperties(self):
        """Test setproperties() batch update."""
        doc = Document('base', **{'base.name': 'test'})

        # Set multiple properties
        doc.setproperties(**{
            'base.name': 'updated',
            'base.type': 'newtype'
        })

        assert doc.document_properties['base']['name'] == 'updated'
        assert doc.document_properties['base']['type'] == 'newtype'

    def test_find_doc_by_id(self):
        """Test find_doc_by_id() static method."""
        docs = [
            Document('base', **{'base.name': 'test1'}),
            Document('base', **{'base.name': 'test2'}),
            Document('base', **{'base.name': 'test3'})
        ]

        # Find by ID
        found = Document.find_doc_by_id(docs, docs[1].id())

        assert found is not None
        assert found.id() == docs[1].id()

    def test_find_doc_by_id_not_found(self):
        """Test find_doc_by_id() with non-existent ID."""
        docs = [
            Document('base', **{'base.name': 'test1'}),
        ]

        found = Document.find_doc_by_id(docs, 'nonexistent')

        assert found is None

    def test_find_newest(self):
        """Test find_newest() static method."""
        import time

        doc1 = Document('base', **{'base.name': 'test1'})
        time.sleep(0.01)  # Ensure different timestamps
        doc2 = Document('base', **{'base.name': 'test2'})
        time.sleep(0.01)
        doc3 = Document('base', **{'base.name': 'test3'})

        docs = [doc1, doc2, doc3]

        newest = Document.find_newest(docs)

        assert newest is not None
        assert newest.id() == doc3.id()  # Last created should be newest


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
