"""
Comprehensive tests for cloud upload module.

Tests upload_document_collection, new_dataset, scan_for_upload,
and zip_for_upload functionality with mocked API calls.
"""

import pytest
import os
import tempfile
import zipfile
from unittest.mock import Mock, patch, MagicMock, call

from ndi.cloud.upload.upload_collection import upload_document_collection
from ndi.cloud.upload.new_dataset import new_dataset
from ndi.cloud.upload.scan_for_upload import scan_for_upload
from ndi.cloud.upload.zip_for_upload import zip_for_upload, _zip_and_upload_batch


class TestUploadDocumentCollection:
    """Tests for upload_document_collection function."""

    def test_upload_batch_mode_success(self):
        """Test successful batch upload with ZIP files."""
        dataset_id = "test_dataset"
        documents = [
            Mock(id=lambda: f"doc{i}", document_properties={'base': {'id': f'doc{i}'}})
            for i in range(3)
        ]

        with patch('ndi.cloud.upload.upload_collection.zip_documents_for_upload') as mock_zip, \
             patch('os.path.exists', return_value=True), \
             patch('os.remove'):

            mock_zip.return_value = ('/tmp/test.zip', ['doc0', 'doc1', 'doc2'])

            success, report = upload_document_collection(
                dataset_id,
                documents,
                only_upload_missing=False,
                verbose=False
            )

            assert success is True
            assert report['uploadType'] == 'batch'
            assert len(report['manifest']) == 1
            assert report['status'][0] == 'success'

    def test_upload_serial_mode(self):
        """Test serial upload mode when NDI_CLOUD_UPLOAD_NO_ZIP is set."""
        dataset_id = "test_dataset"
        documents = [
            Mock(document_properties={'base': {'id': 'doc1'}})
        ]

        with patch.dict(os.environ, {'NDI_CLOUD_UPLOAD_NO_ZIP': 'true'}):
            success, report = upload_document_collection(
                dataset_id,
                documents,
                only_upload_missing=False,
                verbose=False
            )

            assert report['uploadType'] == 'serial'
            assert len(report['manifest']) == 1

    def test_upload_empty_list(self):
        """Test uploading empty document list."""
        with pytest.raises(AssertionError):
            upload_document_collection("dataset_id", [], verbose=False)

    def test_upload_with_chunking(self):
        """Test upload with multiple chunks."""
        dataset_id = "test_dataset"
        documents = [
            Mock(id=lambda i=i: f"doc{i}", document_properties={'base': {'id': f'doc{i}'}})
            for i in range(5)
        ]

        with patch('ndi.cloud.upload.upload_collection.zip_documents_for_upload') as mock_zip, \
             patch('os.path.exists', return_value=True), \
             patch('os.remove'):

            mock_zip.side_effect = [
                ('/tmp/chunk1.zip', ['doc0', 'doc1']),
                ('/tmp/chunk2.zip', ['doc2', 'doc3']),
                ('/tmp/chunk3.zip', ['doc4'])
            ]

            success, report = upload_document_collection(
                dataset_id,
                documents,
                max_document_chunk=2,
                only_upload_missing=False,
                verbose=False
            )

            assert report['uploadType'] == 'batch'
            assert len(report['manifest']) == 3
            assert mock_zip.call_count == 3

    def test_upload_failure_handling(self):
        """Test handling upload failures."""
        dataset_id = "test_dataset"
        documents = [Mock(document_properties={'base': {'id': 'doc1'}})]

        with patch('ndi.cloud.upload.upload_collection.zip_documents_for_upload') as mock_zip:
            mock_zip.side_effect = Exception("Upload failed")

            success, report = upload_document_collection(
                dataset_id,
                documents,
                only_upload_missing=False,
                verbose=False
            )

            assert success is False
            assert 'failure' in report['status']

    def test_upload_no_documents_after_filtering(self):
        """Test when all documents are already uploaded (after filtering)."""
        dataset_id = "test_dataset"
        documents = [Mock(document_properties={'base': {'id': 'doc1'}})]

        # Test the case where document_list becomes empty (should raise assertion error)
        with pytest.raises(AssertionError, match='List of documents was empty'):
            success, report = upload_document_collection(
                dataset_id,
                [],  # Empty after filtering
                only_upload_missing=False,
                verbose=False
            )

            # Should raise assertion error for empty list
            # So we'll test a different approach - just skip the filtering
            # and test the condition where we return early

        # Simulate the scenario where we'd return early
        with pytest.raises(AssertionError):
            upload_document_collection(dataset_id, [], verbose=False)


class TestNewDataset:
    """Tests for new_dataset function."""

    def test_new_dataset_creation(self):
        """Test creating a new dataset."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.upload.new_dataset.print') as mock_print:
            dataset_id = new_dataset(mock_dataset)

            # Currently returns placeholder
            assert dataset_id == "placeholder_dataset_id"
            # Should print warnings about unimplemented functions
            assert mock_print.call_count >= 2


class TestScanForUpload:
    """Tests for scan_for_upload function."""

    def test_scan_new_dataset(self):
        """Test scanning a new dataset."""
        mock_session = Mock()
        mock_session.path = '/tmp/test_session'

        documents = [
            Mock(document_properties={
                'base': {'id': 'doc1'},
                'files': {'file_list': []}
            })
        ]

        doc_structs, file_structs, total_size = scan_for_upload(
            mock_session,
            documents,
            is_new=True,
            verbose=False
        )

        assert len(doc_structs) == 1
        assert doc_structs[0]['docid'] == 'doc1'
        assert doc_structs[0]['is_uploaded'] is False

    def test_scan_with_files(self):
        """Test scanning documents with associated files."""
        mock_session = Mock()
        mock_session.path = '/tmp/test_session'

        # Mock file existence
        with patch('os.path.exists', return_value=True), \
             patch('os.path.getsize', return_value=1024), \
             patch('os.path.join', return_value='/tmp/file.dat'):

            documents = [
                Mock(document_properties={
                    'base': {'id': 'doc1'},
                    'files': {'file_list': ['test_file.dat']}
                })
            ]

            # Note: The current implementation has placeholders for database methods
            # so we can't fully test file scanning without those methods
            doc_structs, file_structs, total_size = scan_for_upload(
                mock_session,
                documents,
                is_new=True,
                verbose=False
            )

            assert len(doc_structs) == 1

    def test_scan_existing_dataset(self):
        """Test scanning an existing dataset."""
        mock_session = Mock()
        mock_session.path = '/tmp/test_session'

        documents = [
            Mock(document_properties={
                'base': {'id': 'doc1'},
                'files': {'file_list': []}
            })
        ]

        # Test with existing dataset (is_new=False)
        with patch('ndi.cloud.upload.scan_for_upload.print') as mock_print:
            doc_structs, file_structs, total_size = scan_for_upload(
                mock_session,
                documents,
                is_new=False,
                dataset_id='existing_dataset_123',
                verbose=False
            )

            # Should warn about unimplemented API functions
            # but still return structures
            assert len(doc_structs) == 1

    def test_scan_multiple_documents(self):
        """Test scanning multiple documents."""
        mock_session = Mock()
        mock_session.path = '/tmp/test_session'

        documents = [
            Mock(document_properties={
                'base': {'id': f'doc{i}'},
                'files': {'file_list': []}
            })
            for i in range(10)
        ]

        doc_structs, file_structs, total_size = scan_for_upload(
            mock_session,
            documents,
            is_new=True,
            verbose=False
        )

        assert len(doc_structs) == 10
        assert all(not doc['is_uploaded'] for doc in doc_structs)

    def test_scan_with_series_files(self):
        """Test scanning documents with file series (ending with #)."""
        mock_session = Mock()
        mock_session.path = '/tmp/test_session'

        documents = [
            Mock(document_properties={
                'base': {'id': 'doc1'},
                'files': {'file_list': ['series_file#']}
            })
        ]

        doc_structs, file_structs, total_size = scan_for_upload(
            mock_session,
            documents,
            is_new=True,
            verbose=False
        )

        assert len(doc_structs) == 1


class TestZipForUpload:
    """Tests for zip_for_upload function."""

    def test_zip_and_upload_success(self):
        """Test successful zip and upload."""
        mock_database = Mock()
        mock_database.path = '/tmp/test_db'

        # Create temporary files to zip
        with tempfile.TemporaryDirectory() as tmpdir:
            file1 = os.path.join(tmpdir, 'file1.dat')
            file2 = os.path.join(tmpdir, 'file2.dat')

            with open(file1, 'wb') as f:
                f.write(b'test data 1')
            with open(file2, 'wb') as f:
                f.write(b'test data 2')

            doc_file_struct = [
                {
                    'uid': 'file1',
                    'name': 'file1.dat',
                    'docid': 'doc1',
                    'bytes': 11,
                    'is_uploaded': False
                },
                {
                    'uid': 'file2',
                    'name': 'file2.dat',
                    'docid': 'doc2',
                    'bytes': 11,
                    'is_uploaded': False
                }
            ]

            with patch('os.path.join', side_effect=lambda *args: os.path.join(*args) if args[0] != mock_database.path else os.path.join(tmpdir, args[-1])), \
                 patch('os.path.isfile', return_value=True):

                # Mock the API calls
                with patch('ndi.cloud.upload.zip_for_upload._zip_and_upload_batch') as mock_zip_upload:
                    mock_zip_upload.return_value = (True, '', 2)

                    success, msg = zip_for_upload(
                        mock_database,
                        doc_file_struct,
                        total_size=22 / 1024,  # in KB
                        dataset_id='test_dataset',
                        verbose=False,
                        debug_log=False
                    )

                    assert success is True
                    assert msg == ''

    def test_zip_skip_uploaded_files(self):
        """Test that already uploaded files are skipped."""
        mock_database = Mock()
        mock_database.path = '/tmp/test_db'

        doc_file_struct = [
            {
                'uid': 'file1',
                'name': 'file1.dat',
                'docid': 'doc1',
                'bytes': 100,
                'is_uploaded': True  # Already uploaded
            }
        ]

        success, msg = zip_for_upload(
            mock_database,
            doc_file_struct,
            total_size=0,
            dataset_id='test_dataset',
            verbose=False,
            debug_log=False
        )

        # Should succeed without uploading anything
        assert success is True

    def test_zip_missing_file(self):
        """Test handling missing files during zip."""
        mock_database = Mock()
        mock_database.path = '/tmp/test_db'

        doc_file_struct = [
            {
                'uid': 'missing_file',
                'name': 'missing.dat',
                'docid': 'doc1',
                'bytes': 100,
                'is_uploaded': False
            }
        ]

        with patch('os.path.join', return_value='/tmp/missing_file'), \
             patch('os.path.isfile', return_value=False):

            import warnings
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter("always")

                success, msg = zip_for_upload(
                    mock_database,
                    doc_file_struct,
                    total_size=100 / 1024,
                    dataset_id='test_dataset',
                    verbose=False,
                    debug_log=False
                )

                # File should be skipped with warning
                assert success is True

    def test_zip_oversized_file(self):
        """Test handling files larger than size limit."""
        mock_database = Mock()
        mock_database.path = '/tmp/test_db'

        doc_file_struct = [
            {
                'uid': 'huge_file',
                'name': 'huge.dat',
                'docid': 'doc1',
                'bytes': 100_000_000,  # 100 MB (larger than default 50 MB limit)
                'is_uploaded': False
            }
        ]

        with patch('os.path.join', return_value='/tmp/huge_file'), \
             patch('os.path.isfile', return_value=True):

            import warnings
            with warnings.catch_warnings(record=True) as w:
                warnings.simplefilter("always")

                success, msg = zip_for_upload(
                    mock_database,
                    doc_file_struct,
                    total_size=100_000_000 / 1024,
                    dataset_id='test_dataset',
                    verbose=False,
                    size_limit=50_000_000,  # 50 MB
                    debug_log=False
                )

                # Should warn about oversized file
                assert len(w) >= 1

    def test_zip_with_debug_logging(self):
        """Test zip with debug logging enabled."""
        mock_database = Mock()
        mock_database.path = '/tmp/test_db'

        doc_file_struct = []  # Empty, nothing to upload

        with patch('tempfile.gettempdir', return_value='/tmp'), \
             patch('os.makedirs'), \
             patch('builtins.open', create=True):

            success, msg = zip_for_upload(
                mock_database,
                doc_file_struct,
                total_size=0,
                dataset_id='test_dataset',
                verbose=False,
                debug_log=True
            )

            assert success is True


class TestZipAndUploadBatch:
    """Tests for _zip_and_upload_batch helper function."""

    def test_batch_upload_success(self):
        """Test successful batch upload."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create test files
            files = []
            for i in range(3):
                filepath = os.path.join(tmpdir, f'file{i}.dat')
                with open(filepath, 'wb') as f:
                    f.write(b'test data')
                files.append(filepath)

            # Mock API calls (not implemented yet, so they'll fail)
            # but we can test the zip creation
            with patch('os.path.getsize', return_value=9), \
                 patch('os.urandom', return_value=b'12345678'):

                success, msg, count = _zip_and_upload_batch(
                    files,
                    'test_dataset',
                    number_retries=1,
                    verbose=False,
                    debug_log=False
                )

                # Will fail because API not implemented, but that's expected
                assert success is False
                assert 'not yet implemented' in msg.lower()
                assert count == 3

    def test_batch_upload_with_logging(self):
        """Test batch upload with debug logging."""
        with tempfile.TemporaryDirectory() as tmpdir:
            log_folder = tmpdir
            filepath = os.path.join(tmpdir, 'testfile.dat')

            with open(filepath, 'wb') as f:
                f.write(b'test')

            with patch('os.path.getsize', return_value=4), \
                 patch('os.urandom', return_value=b'abcdefgh'), \
                 patch('builtins.open', create=True) as mock_open:

                success, msg, count = _zip_and_upload_batch(
                    [filepath],
                    'test_dataset',
                    number_retries=1,
                    verbose=False,
                    debug_log=True,
                    log_folder=log_folder
                )

                # API not implemented, so will fail
                assert success is False


@pytest.fixture
def mock_document():
    """Fixture providing a mock document."""
    doc = Mock()
    doc.id = Mock(return_value='test_doc_id')
    doc.document_properties = {
        'base': {'id': 'test_doc_id'},
        'files': {'file_info': []}
    }
    return doc


@pytest.fixture
def mock_session():
    """Fixture providing a mock session."""
    session = Mock()
    session.path = '/tmp/test_session'
    return session


def test_integration_scan_and_zip(mock_session):
    """Integration test: scan documents and prepare for zip upload."""
    documents = [
        Mock(document_properties={
            'base': {'id': f'doc{i}'},
            'files': {'file_list': []}
        })
        for i in range(3)
    ]

    # Scan for upload
    doc_structs, file_structs, total_size = scan_for_upload(
        mock_session,
        documents,
        is_new=True,
        verbose=False
    )

    assert len(doc_structs) == 3
    assert all(not doc['is_uploaded'] for doc in doc_structs)

    # Since no files, file_structs should be empty
    assert len(file_structs) == 0
    assert total_size == 0.0


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
