"""
Tests for binary file I/O - ported from TestNDIDocument.m
"""

import pytest
import tempfile
import shutil
import os
from pathlib import Path
from ndi import SessionDir, Document, Query


class TestBinaryIO:
    """Test suite for binary file I/O with documents."""

    @pytest.fixture
    def temp_session_dir(self):
        """Create a temporary directory for session testing."""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir)

    @pytest.fixture
    def binary_file(self, temp_session_dir):
        """Create a temporary binary file with known data."""
        filepath = os.path.join(temp_session_dir, 'myfile.bin')

        # Write test data (0-9)
        with open(filepath, 'wb') as f:
            test_data = bytes(range(10))
            f.write(test_data)

        yield filepath, test_data

        # Cleanup
        if os.path.exists(filepath):
            os.remove(filepath)

    def test_document_creation_and_io(self, temp_session_dir, binary_file):
        """Test creating a document with binary file and reading it back."""
        filepath, original_data = binary_file

        # 1. Create session
        session = SessionDir(temp_session_dir, 'exp1')

        # 2. Create a new document
        doc = session.newdocument('base', **{
            'base.name': 'Demo document'
        })

        # Add custom field (simulating 'demoNDI.value')
        doc.document_properties['demo_value'] = 5

        # 3. Add the binary file to the document
        doc.add_file('filename1.ext', filepath)

        # 4. Add document to database
        session.database_add(doc)

        # 5. Search for the document by value
        doc_search1 = session.database_search(
            Query('demo_value', 'exact_number', 5)
        )
        assert len(doc_search1) == 1, "Should find exactly one document by value"

        # 6. Verify reading binary data from the document
        doc_to_read = doc_search1[0]

        # Check if binary file exists
        exists, file_path = session.database.existbinarydoc(doc_to_read, 'filename1.ext')
        assert exists, "Binary file should exist"

        # Open and read binary data
        binarydoc = session.database_openbinarydoc(doc_to_read, 'filename1.ext')
        try:
            data_read = binarydoc.read()
        finally:
            session.database_closebinarydoc(binarydoc)

        # Verify data matches
        assert data_read == original_data, "Read data should match written data"

    def test_multiple_file_attachments(self, temp_session_dir):
        """Test adding multiple files to a single document."""
        session = SessionDir(temp_session_dir, 'test_session')

        # Create test files
        file1_path = os.path.join(temp_session_dir, 'file1.dat')
        file2_path = os.path.join(temp_session_dir, 'file2.dat')

        data1 = b'Test data 1'
        data2 = b'Test data 2'

        with open(file1_path, 'wb') as f:
            f.write(data1)
        with open(file2_path, 'wb') as f:
            f.write(data2)

        # Create document and add both files
        doc = session.newdocument('base', **{'base.name': 'multi_file_doc'})
        doc.add_file('file1.dat', file1_path)
        doc.add_file('file2.dat', file2_path)

        session.database_add(doc)

        # Read back and verify both files
        results = session.database_search(Query('base.name', 'exact_string', 'multi_file_doc'))
        assert len(results) == 1

        doc_read = results[0]

        # Check first file
        exists1, _ = session.database.existbinarydoc(doc_read, 'file1.dat')
        assert exists1

        fh1 = session.database_openbinarydoc(doc_read, 'file1.dat')
        try:
            read_data1 = fh1.read()
        finally:
            session.database_closebinarydoc(fh1)
        assert read_data1 == data1

        # Check second file
        exists2, _ = session.database.existbinarydoc(doc_read, 'file2.dat')
        assert exists2

        fh2 = session.database_openbinarydoc(doc_read, 'file2.dat')
        try:
            read_data2 = fh2.read()
        finally:
            session.database_closebinarydoc(fh2)
        assert read_data2 == data2

    def test_binary_doc_not_found(self, temp_session_dir):
        """Test that opening non-existent binary file raises error."""
        session = SessionDir(temp_session_dir, 'test_session')

        # Create document without binary files
        doc = session.newdocument('base')
        session.database_add(doc)

        # Try to open non-existent file
        with pytest.raises(FileNotFoundError):
            session.database_openbinarydoc(doc, 'nonexistent.dat')

    def test_file_ingestion(self, temp_session_dir, binary_file):
        """Test that files are properly ingested into database."""
        filepath, original_data = binary_file

        session = SessionDir(temp_session_dir, 'test_session')

        # Create document with file (should be ingested)
        doc = session.newdocument('base')
        doc.add_file('test.bin', filepath, ingest=True, delete_original=False)
        session.database_add(doc)

        # Verify file was ingested
        results = session.database_search(session.searchquery())
        assert len(results) == 1

        doc_read = results[0]
        exists, db_path = session.database.existbinarydoc(doc_read, 'test.bin')
        assert exists

        # Verify file is in database directory, not original location
        assert temp_session_dir in db_path
        assert db_path != filepath

    def test_document_removal_removes_binary_files(self, temp_session_dir, binary_file):
        """Test that removing a document also removes associated binary files."""
        filepath, _ = binary_file

        session = SessionDir(temp_session_dir, 'test_session')

        # Create and add document with binary file
        doc = session.newdocument('base')
        doc.add_file('test.bin', filepath)
        session.database_add(doc)

        # Verify file exists
        exists_before, file_path = session.database.existbinarydoc(doc, 'test.bin')
        assert exists_before

        # Remove document
        session.database_rm(doc)

        # Verify binary file is also removed
        assert not os.path.exists(file_path)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
