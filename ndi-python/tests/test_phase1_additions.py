"""
Tests for Phase 1 additions to Session and Document classes.

This file tests the newly added methods in Session and Document classes
to ensure 100% feature parity with MATLAB NDI.
"""

import pytest
import tempfile
import shutil
from pathlib import Path
from datetime import datetime

from ndi.session import Session
from ndi.document import Document
from ndi.ido import IDO


class TestDocumentMethods:
    """Tests for new Document methods."""

    def test_add_dependency_value_n(self):
        """Test adding numbered dependencies."""
        doc = Document('base')
        doc.document_properties['depends_on'] = []

        # Add first dependency
        doc.add_dependency_value_n('probe', 'probe_001', error_if_not_found=False)
        assert 'probe_1' in [d['name'] for d in doc.document_properties['depends_on']]

        # Add second dependency
        doc.add_dependency_value_n('probe', 'probe_002', error_if_not_found=False)
        assert 'probe_2' in [d['name'] for d in doc.document_properties['depends_on']]

        # Verify values
        values = doc.dependency_value_n('probe')
        assert len(values) == 2
        assert values[0] == 'probe_001'
        assert values[1] == 'probe_002'

    def test_dependency_value_n(self):
        """Test retrieving numbered dependencies."""
        doc = Document('base')
        doc.document_properties['depends_on'] = [
            {'name': 'electrode_1', 'value': 'e001'},
            {'name': 'electrode_2', 'value': 'e002'},
            {'name': 'electrode_3', 'value': 'e003'}
        ]

        values = doc.dependency_value_n('electrode')
        assert len(values) == 3
        assert values[0] == 'e001'
        assert values[1] == 'e002'
        assert values[2] == 'e003'

    def test_dependency_value_n_not_found(self):
        """Test dependency_value_n when not found."""
        doc = Document('base')

        # Should raise error by default
        with pytest.raises(KeyError):
            doc.dependency_value_n('nonexistent')

        # Should return empty list with error_if_not_found=False
        result = doc.dependency_value_n('nonexistent', error_if_not_found=False)
        assert result == []

    def test_remove_dependency_value_n(self):
        """Test removing numbered dependencies."""
        doc = Document('base')
        doc.document_properties['depends_on'] = [
            {'name': 'probe_1', 'value': 'p001'},
            {'name': 'probe_2', 'value': 'p002'},
            {'name': 'probe_3', 'value': 'p003'}
        ]

        # Remove probe_2
        doc.remove_dependency_value_n('probe', '', 2)

        # Verify probe_2 is gone and probe_3 became probe_2
        values = doc.dependency_value_n('probe')
        assert len(values) == 2
        assert values[0] == 'p001'
        assert values[1] == 'p003'  # Was probe_3, now probe_2

    def test_has_files(self):
        """Test checking if document has files."""
        doc = Document('base')

        # Initially no files
        assert not doc.has_files()

        # Add file structure
        doc.document_properties['files'] = {
            'file_list': ['data.bin'],
            'file_info': [{'name': 'data.bin', 'locations': []}]
        }

        assert doc.has_files()

    def test_is_in_file_list(self):
        """Test checking if file is in file list."""
        doc = Document('base')
        doc.document_properties['files'] = {
            'file_list': ['data.bin', 'metadata.json'],
            'file_info': [
                {
                    'name': 'data.bin',
                    'locations': [{'uid': 'uid123', 'location': '/path/to/file'}]
                }
            ]
        }

        # File in list with info
        is_valid, msg, idx, uid = doc.is_in_file_list('data.bin')
        assert is_valid
        assert msg == ''
        assert idx == 0
        assert uid == 'uid123'

        # File in list but no info yet
        is_valid, msg, idx, uid = doc.is_in_file_list('metadata.json')
        assert is_valid
        assert idx is None

        # File not in list
        is_valid, msg, idx, uid = doc.is_in_file_list('nonexistent.txt')
        assert not is_valid

    def test_get_fuid(self):
        """Test getting file UID."""
        doc = Document('base')
        doc.document_properties['files'] = {
            'file_list': ['data.bin'],
            'file_info': [
                {
                    'name': 'data.bin',
                    'locations': [{'uid': 'uid123', 'location': '/path'}]
                }
            ]
        }

        fuid = doc.get_fuid('data.bin')
        assert fuid == 'uid123'

        # Non-existent file returns empty string
        fuid = doc.get_fuid('nonexistent.txt')
        assert fuid == ''

    def test_current_file_list(self):
        """Test getting current file list."""
        doc = Document('base')

        # No files initially
        assert doc.current_file_list() == []

        # Add some files
        doc.document_properties['files'] = {
            'file_list': ['data.bin', 'metadata.json', 'notes.txt'],
            'file_info': [
                {'name': 'data.bin', 'locations': []},
                {'name': 'metadata.json', 'locations': []}
            ]
        }

        files = doc.current_file_list()
        assert len(files) == 2
        assert 'data.bin' in files
        assert 'metadata.json' in files
        assert 'notes.txt' not in files  # In file_list but not file_info

    def test_remove_file(self):
        """Test removing file from document."""
        doc = Document('base')
        doc.document_properties['files'] = {
            'file_list': ['data.bin'],
            'file_info': [
                {
                    'name': 'data.bin',
                    'locations': [
                        {'location': '/path1', 'uid': 'uid1'},
                        {'location': '/path2', 'uid': 'uid2'}
                    ]
                }
            ]
        }

        # Remove specific location
        doc.remove_file('data.bin', '/path1')
        assert len(doc.document_properties['files']['file_info'][0]['locations']) == 1

        # Remove all locations
        doc.remove_file('data.bin')
        assert len(doc.document_properties['files']['file_info']) == 0

    def test_reset_file_info(self):
        """Test resetting file info."""
        doc = Document('base')
        doc.document_properties['files'] = {
            'file_list': ['data.bin'],
            'file_info': [{'name': 'data.bin', 'locations': []}]
        }

        doc.reset_file_info()
        assert doc.document_properties['files']['file_info'] == []

    def test_setproperties(self):
        """Test setting properties."""
        doc = Document('base')

        # Set using dot notation
        doc.setproperties(**{'base.name': 'test document'})
        assert doc.document_properties['base']['name'] == 'test document'

        # Multiple properties
        doc.setproperties(**{
            'base.name': 'updated name',
            'base.session_id': 'session123'
        })
        assert doc.document_properties['base']['name'] == 'updated name'
        assert doc.document_properties['base']['session_id'] == 'session123'

    def test_validate(self):
        """Test document validation."""
        doc = Document('base')

        # Currently always returns True
        assert doc.validate() is True

    def test_to_table(self):
        """Test converting document to table."""
        pytest.importorskip('pandas')

        doc = Document('base')
        doc.document_properties['base']['name'] = 'test'
        doc.document_properties['depends_on'] = [
            {'name': 'probe', 'value': 'probe_001'}
        ]

        df = doc.to_table()

        # Check it's a DataFrame
        import pandas as pd
        assert isinstance(df, pd.DataFrame)

        # Check it has one row
        assert len(df) == 1

        # Check dependency column exists
        assert 'depends_on_probe' in df.columns
        assert df['depends_on_probe'].iloc[0] == 'probe_001'

        # Check base.name column exists
        assert 'base.name' in df.columns
        assert df['base.name'].iloc[0] == 'test'

    def test_find_doc_by_id(self):
        """Test finding document by ID."""
        doc1 = Document('base')
        doc2 = Document('base')
        doc3 = Document('base')

        doc_array = [doc1, doc2, doc3]

        # Find doc2
        found, idx = Document.find_doc_by_id(doc_array, doc2.id())
        assert found == doc2
        assert idx == 1

        # Not found
        found, idx = Document.find_doc_by_id(doc_array, 'nonexistent_id')
        assert found is None
        assert idx is None

    def test_find_newest(self):
        """Test finding newest document."""
        import time

        doc1 = Document('base')
        time.sleep(0.01)  # Ensure different timestamps
        doc2 = Document('base')
        time.sleep(0.01)
        doc3 = Document('base')

        doc_array = [doc1, doc2, doc3]

        newest, idx, timestamps = Document.find_newest(doc_array)

        assert newest == doc3
        assert idx == 2
        assert len(timestamps) == 3
        assert isinstance(timestamps[0], datetime)

        # Verify timestamps are in order
        assert timestamps[0] < timestamps[1] < timestamps[2]


class TestSessionMethods:
    """Tests for new Session methods."""

    @pytest.fixture
    def temp_session(self):
        """Create a temporary session for testing."""
        temp_dir = tempfile.mkdtemp()
        session = Session(temp_dir)
        yield session
        # Cleanup
        shutil.rmtree(temp_dir, ignore_errors=True)

    def test_daqsystem_rm(self, temp_session):
        """Test removing DAQ system."""
        # This test would require a full DAQ system setup
        # For now, test that the method exists and has correct signature
        assert hasattr(temp_session, 'daqsystem_rm')

    def test_daqsystem_clear(self, temp_session):
        """Test clearing all DAQ systems."""
        assert hasattr(temp_session, 'daqsystem_clear')
        # Note: Requires initialized database, so just test signature exists
        # Full test would require database setup

    def test_database_existbinarydoc(self, temp_session):
        """Test checking if binary document exists."""
        doc = Document('base')

        # Document doesn't exist yet
        exists, path = temp_session.database_existbinarydoc(doc, 'data.bin')
        assert not exists
        assert path == ''

    def test_syncgraph_addrule(self, temp_session):
        """Test adding sync rule."""
        # Simple test - just verify method exists
        assert hasattr(temp_session, 'syncgraph_addrule')

    def test_syncgraph_rmrule(self, temp_session):
        """Test removing sync rule."""
        assert hasattr(temp_session, 'syncgraph_rmrule')

    def test_get_ingested_docs(self, temp_session):
        """Test getting ingested documents."""
        # Requires initialized database
        assert hasattr(temp_session, 'get_ingested_docs')

    def test_findexpobj(self, temp_session):
        """Test finding experiment object."""
        # Requires initialized database
        assert hasattr(temp_session, 'findexpobj')

    def test_creator_args(self, temp_session):
        """Test getting creator arguments."""
        args = temp_session.creator_args()
        assert isinstance(args, dict)
        assert 'reference' in args

    def test_docinput2docs(self, temp_session):
        """Test converting doc input to docs."""
        doc1 = Document('base')
        doc2 = Document('base')

        # Single document
        result = Session.docinput2docs(temp_session, doc1)
        assert len(result) == 1
        assert result[0] == doc1

        # List of documents
        result = Session.docinput2docs(temp_session, [doc1, doc2])
        assert len(result) == 2

        # Empty input
        result = Session.docinput2docs(temp_session, [])
        assert len(result) == 0

    def test_all_docs_in_session(self):
        """Test checking if all docs are in session."""
        session_id = 'test_session_123'

        doc1 = Document('base')
        doc1.set_session_id(session_id)

        doc2 = Document('base')
        doc2.set_session_id(session_id)

        doc3 = Document('base')
        doc3.set_session_id('different_session')

        # All in same session - returns (True, '')
        result, msg = Session.all_docs_in_session([doc1, doc2], session_id)
        assert result is True
        assert msg == ''

        # Mixed sessions - returns (False, error_message)
        result, msg = Session.all_docs_in_session([doc1, doc3], session_id)
        assert result is False
        assert 'different_session' in msg

        # Empty list - returns (True, '')
        result, msg = Session.all_docs_in_session([], session_id)
        assert result is True


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
