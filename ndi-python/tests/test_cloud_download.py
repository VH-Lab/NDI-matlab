"""
Comprehensive tests for cloud download module.

Tests download_document_collection, jsons_to_documents, download_dataset,
and dataset_documents functionality with mocked API calls.
"""

import pytest
import os
import json
import tempfile
import zipfile
from unittest.mock import Mock, patch, MagicMock, mock_open, call
from pathlib import Path

from ndi.cloud.download.download_collection import download_document_collection
from ndi.cloud.download.jsons2documents import jsons_to_documents
from ndi.cloud.download.dataset import download_dataset
from ndi.cloud.download.dataset_documents import download_dataset_documents


class TestDownloadDocumentCollection:
    """Tests for download_document_collection function."""

    def test_download_with_document_ids(self):
        """Test downloading specific documents with chunking."""
        dataset_id = "test_dataset_123"
        doc_ids = ["doc1", "doc2", "doc3"]

        # Mock the bulk download URL response
        mock_structs = [
            {"document_properties": {"base": {"id": "doc1"}}},
            {"document_properties": {"base": {"id": "doc2"}}},
            {"document_properties": {"base": {"id": "doc3"}}}
        ]

        with patch('ndi.cloud.download.download_collection.docs_api.get_bulk_download_url') as mock_get_url, \
             patch('ndi.cloud.download.download_collection.urllib.request.urlretrieve') as mock_retrieve, \
             patch('ndi.cloud.download.download_collection.zipfile.ZipFile') as mock_zip, \
             patch('ndi.cloud.download.download_collection.tempfile.mkdtemp') as mock_mkdtemp, \
             patch('builtins.open', mock_open(read_data=json.dumps(mock_structs))) as mock_file, \
             patch('ndi.cloud.download.download_collection.structs_to_ndi_documents') as mock_convert, \
             patch('ndi.cloud.download.download_collection.rehydrate_json_nan_null') as mock_rehydrate:

            # Setup mocks
            mock_get_url.return_value = (True, "http://download.url", {})
            mock_mkdtemp.return_value = "/tmp/test_dir"
            mock_rehydrate.return_value = json.dumps(mock_structs)

            # Mock ZipFile context manager
            mock_zip_instance = MagicMock()
            mock_zip_instance.__enter__.return_value = mock_zip_instance
            mock_zip_instance.extractall = MagicMock()
            mock_zip.return_value = mock_zip_instance

            # Mock listdir to return json file
            with patch('os.listdir', return_value=['documents.json']), \
                 patch('os.path.exists', return_value=True), \
                 patch('os.remove'):

                mock_convert.return_value = [Mock() for _ in range(3)]

                result = download_document_collection(
                    dataset_id,
                    document_ids=doc_ids,
                    chunk_size=2,
                    verbose=False
                )

                assert len(result) == 3
                assert mock_get_url.call_count == 2  # 3 docs with chunk_size=2 requires 2 chunks

    def test_download_all_documents(self):
        """Test downloading all documents when no IDs provided."""
        dataset_id = "test_dataset_123"

        with patch('ndi.cloud.download.download_collection.list_remote_document_ids') as mock_list_ids, \
             patch('ndi.cloud.download.download_collection.docs_api.get_bulk_download_url') as mock_get_url, \
             patch('ndi.cloud.download.download_collection.urllib.request.urlretrieve'), \
             patch('ndi.cloud.download.download_collection.zipfile.ZipFile') as mock_zip, \
             patch('ndi.cloud.download.download_collection.tempfile.mkdtemp', return_value="/tmp/test"), \
             patch('builtins.open', mock_open(read_data='[]')), \
             patch('os.listdir', return_value=['docs.json']), \
             patch('os.path.exists', return_value=True), \
             patch('os.remove'), \
             patch('ndi.cloud.download.download_collection.rehydrate_json_nan_null', return_value='[]'), \
             patch('ndi.cloud.download.download_collection.structs_to_ndi_documents', return_value=[]):

            mock_list_ids.return_value = {'apiId': ['api_1', 'api_2'], 'ndi_id': ['ndi_1', 'ndi_2']}
            mock_get_url.return_value = (True, "http://test.url", {})

            # Mock ZipFile
            mock_zip_instance = MagicMock()
            mock_zip_instance.__enter__.return_value = mock_zip_instance
            mock_zip.return_value = mock_zip_instance

            result = download_document_collection(dataset_id, verbose=False)

            mock_list_ids.assert_called_once()

    def test_download_empty_dataset(self):
        """Test downloading from a dataset with no documents."""
        dataset_id = "empty_dataset"

        with patch('ndi.cloud.download.download_collection.list_remote_document_ids') as mock_list_ids:
            mock_list_ids.return_value = {'apiId': [], 'ndi_id': []}

            result = download_document_collection(dataset_id, document_ids=None, verbose=False)

            assert result == []

    def test_download_with_timeout(self):
        """Test download timeout handling."""
        dataset_id = "test_dataset"
        doc_ids = ["doc1"]

        with patch('ndi.cloud.download.download_collection.docs_api.get_bulk_download_url') as mock_get_url, \
             patch('ndi.cloud.download.download_collection.urllib.request.urlretrieve') as mock_retrieve, \
             patch('ndi.cloud.download.download_collection.time.time') as mock_time, \
             patch('os.path.exists', return_value=True), \
             patch('os.remove'):

            mock_get_url.return_value = (True, "http://test.url", {})
            # Simulate retrieval always failing
            mock_retrieve.side_effect = Exception("Connection timeout")
            # Simulate time passing beyond timeout
            mock_time.side_effect = [0, 0, 5, 10, 15, 20, 25]  # Exceeds 20s timeout

            with pytest.raises(RuntimeError, match="Download failed"):
                download_document_collection(
                    dataset_id,
                    document_ids=doc_ids,
                    timeout=20.0,
                    verbose=False
                )

    def test_download_api_error(self):
        """Test handling API errors during bulk download."""
        dataset_id = "test_dataset"
        doc_ids = ["doc1"]

        with patch('ndi.cloud.download.download_collection.docs_api.get_bulk_download_url') as mock_get_url:
            mock_get_url.return_value = (False, None, {"message": "API Error"})

            with pytest.raises(RuntimeError, match="Failed to get bulk download URL"):
                download_document_collection(
                    dataset_id,
                    document_ids=doc_ids,
                    verbose=False
                )


class TestJsonsToDocuments:
    """Tests for jsons_to_documents function."""

    def test_convert_json_files_to_documents(self):
        """Test converting JSON files to document objects."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create test JSON files
            doc1 = {"document_properties": {"base": {"id": "doc1"}}}
            doc2 = {"document_properties": {"base": {"id": "doc2"}}}

            with open(os.path.join(tmpdir, "doc1.json"), "w") as f:
                json.dump(doc1, f)
            with open(os.path.join(tmpdir, "doc2.json"), "w") as f:
                json.dump(doc2, f)

            with patch('ndi.cloud.download.jsons2documents.rehydrate_json_nan_null') as mock_rehydrate:
                mock_rehydrate.side_effect = lambda x: x

                docs = jsons_to_documents(tmpdir)

                assert len(docs) == 2

    def test_convert_legacy_format(self):
        """Test converting legacy JSON format (struct IS document_properties)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Legacy format: no wrapper 'document_properties' key
            legacy_doc = {"base": {"id": "legacy_doc"}}

            with open(os.path.join(tmpdir, "legacy.json"), "w") as f:
                json.dump(legacy_doc, f)

            with patch('ndi.cloud.download.jsons2documents.rehydrate_json_nan_null') as mock_rehydrate:
                mock_rehydrate.side_effect = lambda x: x

                docs = jsons_to_documents(tmpdir)

                assert len(docs) == 1
                assert docs[0].document_properties["base"]["id"] == "legacy_doc"

    def test_empty_directory(self):
        """Test handling empty directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            docs = jsons_to_documents(tmpdir)
            assert docs == []

    def test_invalid_path(self):
        """Test error handling for invalid path."""
        with pytest.raises(ValueError, match="does not exist"):
            jsons_to_documents("/nonexistent/path")

    def test_path_is_file(self):
        """Test error handling when path is a file, not directory."""
        with tempfile.NamedTemporaryFile() as tmpfile:
            with pytest.raises(ValueError, match="not a directory"):
                jsons_to_documents(tmpfile.name)

    def test_corrupt_json_file(self):
        """Test handling corrupt JSON files with warnings."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a corrupt JSON file
            with open(os.path.join(tmpdir, "corrupt.json"), "w") as f:
                f.write("{ this is not valid json }")

            # Create a valid JSON file
            valid_doc = {"document_properties": {"base": {"id": "valid"}}}
            with open(os.path.join(tmpdir, "valid.json"), "w") as f:
                json.dump(valid_doc, f)

            with patch('ndi.cloud.download.jsons2documents.rehydrate_json_nan_null') as mock_rehydrate:
                mock_rehydrate.side_effect = lambda x: x

                import warnings
                with warnings.catch_warnings(record=True) as w:
                    warnings.simplefilter("always")
                    docs = jsons_to_documents(tmpdir)

                    # Should only load the valid document
                    assert len(docs) == 1
                    # Should have issued a warning about the corrupt file
                    assert len(w) >= 1


class TestDownloadDataset:
    """Tests for download_dataset function."""

    def test_download_dataset_local_mode(self):
        """Test downloading dataset in local mode."""
        dataset_id = "test_dataset"
        output_path = "/tmp/test_output"

        mock_dataset = {
            'x_id': dataset_id,
            'name': 'Test Dataset',
            'files': [
                {'uid': 'file1', 'uploaded': True},
                {'uid': 'file2', 'uploaded': True}
            ],
            'documents': ['doc1', 'doc2']
        }

        with patch('os.getenv', return_value='test_token'), \
             patch('os.makedirs'), \
             patch('os.path.isdir', return_value=False), \
             patch('ndi.cloud.download.dataset.datasets.get_dataset') as mock_get_dataset, \
             patch('ndi.cloud.download.dataset.files_api.get_file_details') as mock_get_file, \
             patch('ndi.cloud.download.dataset.urllib.request.urlretrieve'), \
             patch('ndi.cloud.download.dataset.download_dataset_documents') as mock_download_docs, \
             patch('ndi.cloud.download.dataset.jsons_to_documents') as mock_jsons, \
             patch('ndi.cloud.download.dataset.DatasetDir') as mock_dataset_dir, \
             patch('os.path.isfile', return_value=False):

            mock_get_dataset.return_value = (True, mock_dataset, None, None)
            mock_get_file.return_value = (True, {'downloadUrl': 'http://file.url'}, None, None)
            mock_download_docs.return_value = (True, '')
            mock_jsons.return_value = []
            mock_dataset_dir.return_value = Mock()

            success, msg, dataset = download_dataset(
                dataset_id,
                mode='local',
                output_path=output_path,
                verbose=False
            )

            assert success is True
            mock_get_dataset.assert_called_once()

    def test_download_dataset_hybrid_mode(self):
        """Test downloading dataset in hybrid mode (no file downloads)."""
        dataset_id = "test_dataset"
        output_path = "/tmp/test_output"

        mock_dataset = {
            'x_id': dataset_id,
            'name': 'Test Dataset',
            'files': [],
            'documents': ['doc1']
        }

        with patch('os.getenv', return_value='test_token'), \
             patch('os.makedirs'), \
             patch('os.path.isdir', return_value=False), \
             patch('ndi.cloud.download.dataset.datasets.get_dataset') as mock_get_dataset, \
             patch('ndi.cloud.download.dataset.download_dataset_documents') as mock_download_docs, \
             patch('ndi.cloud.download.dataset.jsons_to_documents') as mock_jsons, \
             patch('ndi.cloud.download.dataset.DatasetDir') as mock_dataset_dir:

            mock_get_dataset.return_value = (True, mock_dataset, None, None)
            mock_download_docs.return_value = (True, '')
            mock_jsons.return_value = []
            mock_dataset_dir.return_value = Mock()

            success, msg, dataset = download_dataset(
                dataset_id,
                mode='hybrid',
                output_path=output_path,
                verbose=False
            )

            assert success is True

    def test_download_invalid_mode(self):
        """Test error handling for invalid mode."""
        success, msg, dataset = download_dataset(
            "test_dataset",
            mode='invalid_mode',
            output_path='/tmp/test',
            verbose=False
        )

        assert success is False
        assert 'Invalid mode' in msg

    def test_download_missing_output_path(self):
        """Test error handling when output_path is not provided."""
        success, msg, dataset = download_dataset(
            "test_dataset",
            mode='local',
            output_path=None,
            verbose=False
        )

        assert success is False
        assert 'output_path must be provided' in msg

    def test_download_missing_token(self):
        """Test error handling when authentication token is missing."""
        with patch('os.getenv', return_value=None):
            success, msg, dataset = download_dataset(
                "test_dataset",
                mode='local',
                output_path='/tmp/test',
                verbose=False
            )

            assert success is False
            assert 'authentication token' in msg.lower()

    def test_download_api_failure(self):
        """Test handling API failure during dataset retrieval."""
        with patch('os.getenv', return_value='test_token'), \
             patch('os.makedirs'), \
             patch('os.path.isdir', return_value=False), \
             patch('ndi.cloud.download.dataset.datasets.get_dataset') as mock_get_dataset:

            mock_get_dataset.return_value = (False, {'message': 'API Error'}, None, None)

            success, msg, dataset = download_dataset(
                "test_dataset",
                mode='local',
                output_path='/tmp/test',
                verbose=False
            )

            assert success is False
            assert 'Failed to get dataset' in msg


class TestDownloadDatasetDocuments:
    """Tests for download_dataset_documents function."""

    def test_download_documents_local_mode(self):
        """Test downloading documents in local mode."""
        mock_dataset = {
            'x_id': 'dataset123',
            'documents': ['doc1', 'doc2']
        }

        mock_doc = {
            'id': 'doc1',
            'base': {'id': 'ndi_doc1'},
            'files': {'file_info': []}
        }

        with patch('os.getenv', return_value='test_token'), \
             patch('os.path.isdir', return_value=True), \
             patch('os.path.isfile', return_value=False), \
             patch('ndi.cloud.download.dataset_documents.docs_api.get_document') as mock_get_doc, \
             patch('builtins.open', mock_open()):

            mock_get_doc.return_value = (True, mock_doc, None, None)

            with tempfile.TemporaryDirectory() as json_path, \
                 tempfile.TemporaryDirectory() as file_path:

                success, msg = download_dataset_documents(
                    mock_dataset,
                    'local',
                    json_path,
                    file_path,
                    verbose=False
                )

                assert success is True

    def test_download_documents_hybrid_mode(self):
        """Test downloading documents in hybrid mode."""
        mock_dataset = {
            'x_id': 'dataset123',
            'documents': ['doc1']
        }

        mock_doc = {
            'base': {'id': 'ndi_doc1'},
            'files': {'file_info': [{'locations': [{'uid': 'file1'}]}]}
        }

        with patch('os.getenv', return_value='test_token'), \
             patch('os.path.isdir', return_value=True), \
             patch('os.path.isfile', return_value=False), \
             patch('ndi.cloud.download.dataset_documents.docs_api.get_document') as mock_get_doc, \
             patch('builtins.open', mock_open()):

            mock_get_doc.return_value = (True, mock_doc, None, None)

            with tempfile.TemporaryDirectory() as json_path, \
                 tempfile.TemporaryDirectory() as file_path:

                success, msg = download_dataset_documents(
                    mock_dataset,
                    'hybrid',
                    json_path,
                    file_path,
                    verbose=False
                )

                assert success is True

    def test_skip_existing_documents(self):
        """Test that existing documents are skipped."""
        mock_dataset = {
            'x_id': 'dataset123',
            'documents': ['doc1']
        }

        with patch('os.getenv', return_value='test_token'), \
             patch('os.path.isdir', return_value=True), \
             patch('os.path.isfile', return_value=True):  # Document already exists

            with tempfile.TemporaryDirectory() as json_path, \
                 tempfile.TemporaryDirectory() as file_path:

                success, msg = download_dataset_documents(
                    mock_dataset,
                    'local',
                    json_path,
                    file_path,
                    verbose=False
                )

                assert success is True

    def test_invalid_mode(self):
        """Test error handling for invalid mode."""
        mock_dataset = {'x_id': 'test', 'documents': []}

        with tempfile.TemporaryDirectory() as json_path, \
             tempfile.TemporaryDirectory() as file_path:

            success, msg = download_dataset_documents(
                mock_dataset,
                'invalid_mode',
                json_path,
                file_path,
                verbose=False
            )

            assert success is False
            assert 'Invalid mode' in msg

    def test_invalid_paths(self):
        """Test error handling for invalid directory paths."""
        mock_dataset = {'x_id': 'test', 'documents': []}

        success, msg = download_dataset_documents(
            mock_dataset,
            'local',
            '/nonexistent/json/path',
            '/nonexistent/file/path',
            verbose=False
        )

        assert success is False
        assert 'does not exist' in msg.lower()


@pytest.fixture
def sample_document_struct():
    """Fixture providing sample document structure."""
    return {
        "document_properties": {
            "base": {"id": "test_doc_1"},
            "definition": {"type": "test.document"},
            "files": {
                "file_info": [
                    {
                        "name": "test_file.dat",
                        "locations": [{"uid": "uid123", "file_path": "/tmp/file.dat"}]
                    }
                ]
            }
        }
    }


def test_integration_download_and_convert():
    """Integration test: download documents and convert JSONs."""
    with tempfile.TemporaryDirectory() as tmpdir:
        json_dir = os.path.join(tmpdir, 'json')
        os.makedirs(json_dir)

        # Create sample JSON file
        sample_doc = {
            "document_properties": {
                "base": {"id": "integration_test_doc"}
            }
        }

        with open(os.path.join(json_dir, 'doc1.json'), 'w') as f:
            json.dump(sample_doc, f)

        with patch('ndi.cloud.download.jsons2documents.rehydrate_json_nan_null') as mock_rehydrate:
            mock_rehydrate.side_effect = lambda x: x

            docs = jsons_to_documents(json_dir)

            assert len(docs) == 1
            assert docs[0].document_properties['base']['id'] == 'integration_test_doc'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
