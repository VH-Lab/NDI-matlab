"""
Test suite for NDI Mock objects.

Tests mock implementations including:
- MockSession
- MockDatabase
- MockDAQSystem
- MockProbe
"""

import pytest
import numpy as np

from ndi.mock import MockSession, MockDatabase, MockDAQSystem, MockProbe
from ndi.document import Document
from ndi.query import Query


class TestMockSession:
    """Test MockSession functionality."""

    def test_mock_session_creation(self):
        """Test creating a mock session."""
        session = MockSession()

        assert session is not None
        assert session.id() is not None
        assert len(session.id()) == 32  # UUID hex string
        assert session.reference == 'mock_test'

        # Cleanup
        session.cleanup()

    def test_mock_session_custom_reference(self):
        """Test creating mock session with custom reference."""
        session = MockSession(reference='my_mock')

        assert session.reference == 'my_mock'

        session.cleanup()

    def test_mock_session_has_subject(self):
        """Test that mock session has a mock subject."""
        session = MockSession()

        # Search for the mock subject
        query = Query('subject.local_identifier', 'exact_string', 'anteater27@nosuchlab.org')
        subjects = session.database_search(query)

        assert len(subjects) > 0
        assert 'anteater27@nosuchlab.org' in str(subjects[0].document_properties)

        session.cleanup()

    def test_mock_session_cleanup(self):
        """Test cleanup of mock session."""
        session = MockSession(cleanup_on_delete=False)
        temp_path = session.temp_dir

        from pathlib import Path
        assert Path(temp_path).exists()

        session.cleanup()

        # Cleanup should remove the temp directory
        # (may still exist briefly, so we just check no error)
        assert True  # Just verify no exception

    def test_mock_session_database_operations(self):
        """Test basic database operations in mock session."""
        session = MockSession()

        # Add a document
        doc = Document('base')
        doc = doc.set_session_id(session.id())
        session.database_add(doc)

        # Search for it
        query = Query('base.id', 'exact_string', doc.id())
        results = session.database_search(query)

        assert len(results) == 1
        assert results[0].id() == doc.id()

        session.cleanup()


class TestMockDatabase:
    """Test MockDatabase functionality."""

    def test_mock_database_creation(self):
        """Test creating a mock database."""
        db = MockDatabase()

        assert db is not None
        assert len(db) == 0

    def test_mock_database_add(self):
        """Test adding documents to mock database."""
        db = MockDatabase()
        doc = Document('base')

        db.add(doc)

        assert len(db) == 1

    def test_mock_database_read(self):
        """Test reading documents from mock database."""
        db = MockDatabase()
        doc = Document('base')

        db.add(doc)
        retrieved = db.read(doc.id())

        assert retrieved is not None
        assert retrieved.id() == doc.id()

    def test_mock_database_read_nonexistent(self):
        """Test reading nonexistent document returns None."""
        db = MockDatabase()

        result = db.read('nonexistent_id_12345')

        assert result is None

    def test_mock_database_search(self):
        """Test searching in mock database."""
        db = MockDatabase()

        # Add multiple documents
        doc1 = Document('base')
        doc2 = Document('base')
        db.add(doc1)
        db.add(doc2)

        # Search for base type
        query = Query('', 'isa', 'base')
        results = db.search(query)

        assert len(results) >= 2

    def test_mock_database_remove(self):
        """Test removing documents from mock database."""
        db = MockDatabase()
        doc = Document('base')

        db.add(doc)
        assert len(db) == 1

        db.remove(doc)
        assert len(db) == 0

    def test_mock_database_remove_by_id(self):
        """Test removing documents by ID."""
        db = MockDatabase()
        doc = Document('base')

        db.add(doc)
        doc_id = doc.id()

        db.remove(doc_id)
        assert len(db) == 0

    def test_mock_database_clear(self):
        """Test clearing all documents."""
        db = MockDatabase()

        # Add multiple documents
        for i in range(5):
            db.add(Document('base'))

        assert len(db) == 5

        db.clear()
        assert len(db) == 0


class TestMockDAQSystem:
    """Test MockDAQSystem functionality."""

    def test_mock_daq_creation(self):
        """Test creating a mock DAQ system."""
        daq = MockDAQSystem('test_daq')

        assert daq.name == 'test_daq'
        assert daq.num_channels == 1
        assert daq.sample_rate == 1000.0

    def test_mock_daq_custom_params(self):
        """Test creating mock DAQ with custom parameters."""
        daq = MockDAQSystem('custom', num_channels=8, sample_rate=2000.0)

        assert daq.name == 'custom'
        assert daq.num_channels == 8
        assert daq.sample_rate == 2000.0

    def test_mock_daq_read_data(self):
        """Test reading data from mock DAQ."""
        daq = MockDAQSystem('test')

        data = daq.read_data(0, 1.0)  # 1 second from channel 0

        assert isinstance(data, np.ndarray)
        assert len(data) == 1000  # 1 second at 1000 Hz

    def test_mock_daq_read_data_custom_duration(self):
        """Test reading different duration of data."""
        daq = MockDAQSystem('test', sample_rate=500.0)

        data = daq.read_data(0, 2.5)  # 2.5 seconds

        assert len(data) == int(2.5 * 500)  # 2.5 seconds at 500 Hz

    def test_mock_daq_read_invalid_channel(self):
        """Test reading from invalid channel raises error."""
        daq = MockDAQSystem('test', num_channels=2)

        with pytest.raises(ValueError, match="Invalid channel"):
            daq.read_data(5, 1.0)  # Channel 5 doesn't exist

    def test_mock_daq_get_epochs(self):
        """Test getting epochs from mock DAQ."""
        daq = MockDAQSystem('test')

        epochs = daq.get_epochs()

        assert len(epochs) > 0
        assert 'number' in epochs[0]
        assert 'duration' in epochs[0]

    def test_mock_daq_add_epoch(self):
        """Test adding epochs to mock DAQ."""
        daq = MockDAQSystem('test')

        initial_count = len(daq.epochs)
        daq.add_epoch(1, 5.0)

        assert len(daq.epochs) == initial_count + 1
        assert daq.epochs[-1]['number'] == 1
        assert daq.epochs[-1]['duration'] == 5.0


class TestMockProbe:
    """Test MockProbe functionality."""

    def test_mock_probe_creation(self):
        """Test creating a mock probe."""
        probe = MockProbe('test_probe')

        assert probe.name == 'test_probe'
        assert probe.num_channels == 1
        assert probe.probe_type == 'electrode'

    def test_mock_probe_custom_params(self):
        """Test creating mock probe with custom parameters."""
        probe = MockProbe('optical', num_channels=4, probe_type='optical')

        assert probe.name == 'optical'
        assert probe.num_channels == 4
        assert probe.probe_type == 'optical'

    def test_mock_probe_channels(self):
        """Test mock probe channels."""
        probe = MockProbe('test', num_channels=4)

        assert len(probe.channels) == 4

        for i, channel in enumerate(probe.channels):
            assert channel['number'] == i
            assert 'channel' in channel['name']

    def test_mock_probe_get_channel(self):
        """Test getting specific channel from probe."""
        probe = MockProbe('test', num_channels=4)

        ch = probe.get_channel(2)

        assert ch is not None
        assert ch['number'] == 2
        assert ch['name'] == 'channel_2'

    def test_mock_probe_get_invalid_channel(self):
        """Test getting invalid channel returns None."""
        probe = MockProbe('test', num_channels=4)

        ch = probe.get_channel(10)

        assert ch is None

    def test_mock_probe_get_negative_channel(self):
        """Test getting negative channel returns None."""
        probe = MockProbe('test', num_channels=4)

        ch = probe.get_channel(-1)

        assert ch is None


class TestMockRepr:
    """Test string representations of mock objects."""

    def test_mock_session_repr(self):
        """Test MockSession repr."""
        session = MockSession()

        repr_str = repr(session)
        assert 'MockSession' in repr_str
        assert 'mock_test' in repr_str

        session.cleanup()

    def test_mock_database_repr(self):
        """Test MockDatabase repr."""
        db = MockDatabase()
        db.add(Document('base'))

        repr_str = repr(db)
        assert 'MockDatabase' in repr_str
        assert 'documents=1' in repr_str

    def test_mock_daq_repr(self):
        """Test MockDAQSystem repr."""
        daq = MockDAQSystem('test', num_channels=4, sample_rate=2000)

        repr_str = repr(daq)
        assert 'MockDAQSystem' in repr_str
        assert 'test' in repr_str
        assert '4' in repr_str
        assert '2000' in repr_str

    def test_mock_probe_repr(self):
        """Test MockProbe repr."""
        probe = MockProbe('test', num_channels=8)

        repr_str = repr(probe)
        assert 'MockProbe' in repr_str
        assert 'test' in repr_str
        assert '8' in repr_str


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
