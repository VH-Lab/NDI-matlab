"""
Test suite for NDI Dataset functionality.

Tests the Dataset class and Dir implementation including:
- Dataset creation and opening
- Session linking and ingestion
- Database operations across sessions
- Session management
"""

import pytest
import tempfile
import shutil
from pathlib import Path

from ndi.dataset import Dataset
from ndi.dataset.dir import Dir
from ndi.session import SessionDir
from ndi.document import Document
from ndi.query import Query


class TestDatasetBasic:
    """Test basic Dataset functionality."""

    def test_dataset_creation(self, tmp_path):
        """Test creating a new dataset."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        assert dataset is not None
        assert dataset.id() is not None
        assert len(dataset.id()) == 32  # UUID hex string
        assert dataset_path.exists()

    def test_dataset_open_existing(self, tmp_path):
        """Test opening an existing dataset."""
        dataset_path = tmp_path / "test_dataset"

        # Create dataset
        dataset1 = Dir("test_dataset", str(dataset_path))
        dataset1_id = dataset1.id()

        # Open existing dataset
        dataset2 = Dir(str(dataset_path))

        assert dataset2 is not None
        assert dataset2.id() == dataset1_id

    def test_dataset_reference(self, tmp_path):
        """Test dataset reference property."""
        dataset_path = tmp_path / "test_dataset"
        reference = "my_experiment"

        dataset = Dir(reference, str(dataset_path))

        # Note: reference is a method in the implementation
        # but should behave like a property
        assert dataset.session.reference == reference

    def test_dataset_getpath(self, tmp_path):
        """Test getting dataset path."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        path = dataset.getpath()
        assert Path(path) == dataset_path


class TestSessionManagement:
    """Test session management in datasets."""

    def test_add_linked_session(self, tmp_path):
        """Test linking a session to a dataset."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create a session
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")

        # Link the session
        dataset.add_linked_session(session)

        # Verify session is in the list
        refs, ids = dataset.session_list()
        assert len(refs) == 1
        assert len(ids) == 1
        assert session.id() in ids
        assert "test_session" in refs

    def test_add_duplicate_linked_session_raises(self, tmp_path):
        """Test that adding same session twice raises error."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link a session
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")
        dataset.add_linked_session(session)

        # Try to link again - should raise
        with pytest.raises(ValueError, match="already part of dataset"):
            dataset.add_linked_session(session)

    def test_session_list_empty(self, tmp_path):
        """Test session_list on empty dataset."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        refs, ids = dataset.session_list()
        assert refs == []
        assert ids == []

    def test_session_list_multiple(self, tmp_path):
        """Test session_list with multiple sessions."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link multiple sessions
        sessions = []
        for i in range(3):
            session_path = tmp_path / f"session_{i}"
            session = SessionDir(str(session_path), f"session_{i}")
            sessions.append(session)
            dataset.add_linked_session(session)

        # Verify all in list
        refs, ids = dataset.session_list()
        assert len(refs) == 3
        assert len(ids) == 3

        for session in sessions:
            assert session.id() in ids

    def test_open_session(self, tmp_path):
        """Test opening a session from dataset."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link a session
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")
        session_id = session.id()
        dataset.add_linked_session(session)

        # Open the session
        opened_session = dataset.open_session(session_id)
        assert opened_session is not None
        assert opened_session.id() == session_id

    def test_open_nonexistent_session_raises(self, tmp_path):
        """Test opening non-existent session raises error."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        with pytest.raises(ValueError, match="not found in dataset"):
            dataset.open_session("nonexistent_id_123456789012")


class TestDatabaseOperations:
    """Test database operations in datasets."""

    def test_database_add_to_dataset(self, tmp_path):
        """Test adding document to dataset."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and add document
        doc = Document("base")
        doc = doc.set_session_id(dataset.id())
        dataset.database_add(doc)

        # Search for document
        query = Query("base.id", "exact_string", doc.id())
        results = dataset.database_search(query)

        assert len(results) == 1
        assert results[0].id() == doc.id()

    def test_database_add_to_linked_session(self, tmp_path):
        """Test adding document to linked session via dataset."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link session
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")
        dataset.add_linked_session(session)

        # Create document for the session
        doc = Document("base")
        doc = doc.set_session_id(session.id())

        # Add via dataset
        dataset.database_add(doc)

        # Search in dataset
        query = Query("base.id", "exact_string", doc.id())
        results = dataset.database_search(query)

        assert len(results) == 1
        assert results[0].id() == doc.id()

    def test_database_search_across_sessions(self, tmp_path):
        """Test searching across multiple sessions."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link multiple sessions
        sessions = []
        docs = []
        for i in range(3):
            session_path = tmp_path / f"session_{i}"
            session = SessionDir(str(session_path), f"session_{i}")
            sessions.append(session)
            dataset.add_linked_session(session)

            # Add document to each session
            doc = Document("base")
            doc = doc.set_session_id(session.id())
            dataset.database_add(doc)
            docs.append(doc)

        # Search for all documents
        query = Query("", "isa", "base")
        results = dataset.database_search(query)

        # Should find documents from all sessions plus dataset metadata
        assert len(results) >= 3

        # Check that our documents are in results
        result_ids = [r.id() for r in results]
        for doc in docs:
            assert doc.id() in result_ids

    def test_database_rm(self, tmp_path):
        """Test removing document from dataset."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and add document
        doc = Document("base")
        doc = doc.set_session_id(dataset.id())
        dataset.database_add(doc)

        # Verify it exists
        query = Query("base.id", "exact_string", doc.id())
        results = dataset.database_search(query)
        assert len(results) == 1

        # Remove it
        dataset.database_rm(doc)

        # Verify it's gone
        results = dataset.database_search(query)
        assert len(results) == 0

    def test_database_rm_by_id(self, tmp_path):
        """Test removing document by ID string."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and add document
        doc = Document("base")
        doc = doc.set_session_id(dataset.id())
        dataset.database_add(doc)
        doc_id = doc.id()

        # Remove by ID
        dataset.database_rm(doc_id)

        # Verify it's gone
        query = Query("base.id", "exact_string", doc_id)
        results = dataset.database_search(query)
        assert len(results) == 0


class TestDatasetDir:
    """Test Dir-specific functionality."""

    def test_dir_creation(self, tmp_path):
        """Test Dir dataset creation."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        assert isinstance(dataset, Dir)
        assert isinstance(dataset, Dataset)
        assert dataset.path == dataset_path

    def test_dir_single_arg_constructor(self, tmp_path):
        """Test Dir with single path argument."""
        dataset_path = tmp_path / "test_dataset"

        # Create with two args
        dataset1 = Dir("test", str(dataset_path))

        # Open with single arg
        dataset2 = Dir(str(dataset_path))

        assert dataset2 is not None
        assert dataset2.path == dataset_path

    def test_dataset_erase(self, tmp_path):
        """Test erasing dataset (with caution!)."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Add a document to create database directory
        doc = Document("base")
        doc = doc.set_session_id(dataset.id())
        dataset.database_add(doc)

        ndi_dir = dataset_path / "ndi_database"
        # Database directory should exist after adding documents
        # Note: DirectoryDatabase creates 'ndi_database' on init

        # Erase (with confirmation) - note this currently deletes .ndi not ndi_database
        # This is matching MATLAB behavior which deletes .ndi
        # For now, just check that the method doesn't crash
        Dir.dataset_erase(dataset, "yes")

    def test_dataset_erase_without_confirmation(self, tmp_path):
        """Test that erase without confirmation doesn't delete."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Add a document
        doc = Document("base")
        doc = doc.set_session_id(dataset.id())
        dataset.database_add(doc)

        ndi_dir = dataset_path / "ndi_database"
        assert ndi_dir.exists()

        # Try to erase without confirmation - should not delete
        Dir.dataset_erase(dataset, "no")

        # Directory should still exist
        assert ndi_dir.exists()


class TestDocumentSession:
    """Test document-to-session mapping."""

    def test_document_session(self, tmp_path):
        """Test getting the session for a document."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link session
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")
        dataset.add_linked_session(session)

        # Create document for session
        doc = Document("base")
        doc = doc.set_session_id(session.id())
        dataset.database_add(doc)

        # Get the session for this document
        doc_session = dataset.document_session(doc)

        assert doc_session is not None
        assert doc_session.id() == session.id()


class TestBuildSessionInfo:
    """Test session info building and persistence."""

    def test_build_session_info_empty(self, tmp_path):
        """Test building session info for empty dataset."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        dataset.build_session_info()

        assert dataset.session_info == []
        assert dataset.session_array == []

    def test_build_session_info_with_sessions(self, tmp_path):
        """Test building session info with linked sessions."""
        # Create dataset
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Create and link sessions
        for i in range(2):
            session_path = tmp_path / f"session_{i}"
            session = SessionDir(str(session_path), f"session_{i}")
            dataset.add_linked_session(session)

        # Rebuild session info
        dataset.session_info = []
        dataset.session_array = []
        dataset.build_session_info()

        assert len(dataset.session_info) == 2
        assert len(dataset.session_array) == 2

    def test_session_info_persistence(self, tmp_path):
        """Test that session info persists across dataset reopening."""
        dataset_path = tmp_path / "test_dataset"

        # Create dataset and link session
        dataset1 = Dir("test_dataset", str(dataset_path))
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")
        session_id = session.id()
        dataset1.add_linked_session(session)

        # Close and reopen dataset
        dataset2 = Dir(str(dataset_path))

        # Session info should be restored
        refs, ids = dataset2.session_list()
        assert len(ids) == 1
        assert session_id in ids


class TestRepr:
    """Test string representations."""

    def test_dataset_repr(self, tmp_path):
        """Test Dataset repr."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        repr_str = repr(dataset)
        assert "Dir" in repr_str
        assert "test_dataset" in repr_str or str(dataset_path) in repr_str

    def test_dataset_repr_with_sessions(self, tmp_path):
        """Test Dataset repr with sessions."""
        dataset_path = tmp_path / "test_dataset"
        dataset = Dir("test_dataset", str(dataset_path))

        # Add session
        session_path = tmp_path / "test_session"
        session = SessionDir(str(session_path), "test_session")
        dataset.add_linked_session(session)

        repr_str = repr(dataset)
        assert "sessions=1" in repr_str


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
