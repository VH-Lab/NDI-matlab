"""
Comprehensive tests for cloud sync module.

Tests two_way_sync, mirror_to_remote, mirror_from_remote, upload_new,
download_new, SyncOptions, and SyncMode functionality.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock, call

from ndi.cloud.sync.two_way_sync import two_way_sync
from ndi.cloud.sync.mirror_to_remote import mirror_to_remote
from ndi.cloud.sync.mirror_from_remote import mirror_from_remote
from ndi.cloud.sync.upload_new import upload_new
from ndi.cloud.sync.download_new import download_new
from ndi.cloud.sync.sync_options import SyncOptions
from ndi.cloud.sync.sync_mode import SyncMode


class TestSyncOptions:
    """Tests for SyncOptions class."""

    def test_default_options(self):
        """Test default sync options."""
        opts = SyncOptions()

        assert opts.sync_files is False
        assert opts.verbose is True
        assert opts.dry_run is False
        assert opts.file_upload_strategy == 'batch'

    def test_custom_options(self):
        """Test creating custom sync options."""
        opts = SyncOptions(
            sync_files=True,
            verbose=False,
            dry_run=True,
            file_upload_strategy='serial'
        )

        assert opts.sync_files is True
        assert opts.verbose is False
        assert opts.dry_run is True
        assert opts.file_upload_strategy == 'serial'

    def test_invalid_upload_strategy(self):
        """Test error handling for invalid upload strategy."""
        with pytest.raises(ValueError, match="file_upload_strategy must be"):
            SyncOptions(file_upload_strategy='invalid')

    def test_to_dict(self):
        """Test converting options to dictionary."""
        opts = SyncOptions(sync_files=True, verbose=False)
        opts_dict = opts.to_dict()

        assert opts_dict['sync_files'] is True
        assert opts_dict['verbose'] is False
        assert 'dry_run' in opts_dict
        assert 'file_upload_strategy' in opts_dict

    def test_repr(self):
        """Test string representation."""
        opts = SyncOptions()
        repr_str = repr(opts)

        assert 'SyncOptions' in repr_str
        assert 'sync_files' in repr_str

    def test_camel_to_snake_conversion(self):
        """Test camelCase to snake_case conversion."""
        opts = SyncOptions(syncFiles=True, dryRun=True)

        assert opts.sync_files is True
        assert opts.dry_run is True


class TestSyncMode:
    """Tests for SyncMode enum."""

    def test_sync_mode_values(self):
        """Test sync mode enum values."""
        assert SyncMode.DOWNLOAD_NEW.value == "downloadNew"
        assert SyncMode.MIRROR_FROM_REMOTE.value == "mirrorFromRemote"
        assert SyncMode.UPLOAD_NEW.value == "uploadNew"
        assert SyncMode.MIRROR_TO_REMOTE.value == "mirrorToRemote"
        assert SyncMode.TWO_WAY_SYNC.value == "twoWaySync"

    def test_sync_mode_execute(self):
        """Test executing sync mode."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'
        opts = SyncOptions(verbose=False)

        with patch('ndi.cloud.sync.sync_mode.download_new') as mock_download:
            SyncMode.DOWNLOAD_NEW.execute(mock_dataset, opts)
            mock_download.assert_called_once()


class TestTwoWaySync:
    """Tests for two_way_sync function."""

    def test_two_way_sync_with_uploads_and_downloads(self):
        """Test bidirectional sync with both uploads and downloads."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        local_docs = [Mock(), Mock()]
        local_ids = ['local1', 'local2']
        remote_map = {'ndi_id': ['remote1', 'remote2'], 'api_id': ['api1', 'api2']}

        with patch('ndi.cloud.sync.two_way_sync.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.two_way_sync.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.two_way_sync.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.two_way_sync.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.two_way_sync.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.two_way_sync.upload_files_for_dataset_documents') as mock_upload_files, \
             patch('ndi.cloud.sync.two_way_sync.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'

            # Initial state: local has doc1, remote has doc2
            mock_list_local.side_effect = [
                (local_docs[:1], ['local1']),  # Initial
                ([Mock()], ['local1', 'remote2'])  # Final (after download)
            ]
            mock_list_remote.side_effect = [
                {'ndi_id': ['remote2'], 'api_id': ['api2']},  # Initial
                {'ndi_id': ['remote2', 'local1'], 'api_id': ['api2', 'api_local1']},  # After upload
                {'ndi_id': ['remote2', 'local1'], 'api_id': ['api2', 'api_local1']}  # Final
            ]

            two_way_sync(mock_dataset, verbose=False, sync_files=False)

            # Should upload local1 (not on remote)
            mock_upload.assert_called()
            # Should download remote2 (not on local)
            mock_download.assert_called()
            # Should update index
            mock_update_index.assert_called_once()

    def test_two_way_sync_dry_run(self):
        """Test two-way sync in dry run mode."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.two_way_sync.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.two_way_sync.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.two_way_sync.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.two_way_sync.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.two_way_sync.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.two_way_sync.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            mock_list_local.return_value = ([Mock()], ['local1'])
            mock_list_remote.return_value = {'ndi_id': ['remote1'], 'api_id': ['api1']}

            two_way_sync(mock_dataset, verbose=False, dry_run=True)

            # In dry run, should not actually upload/download
            mock_upload.assert_not_called()
            mock_download.assert_not_called()
            mock_update_index.assert_not_called()

    def test_two_way_sync_no_changes(self):
        """Test two-way sync when datasets are already in sync."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.two_way_sync.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.two_way_sync.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.two_way_sync.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.two_way_sync.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.two_way_sync.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.two_way_sync.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Same documents on both sides
            mock_list_local.return_value = ([Mock()], ['doc1', 'doc2'])
            mock_list_remote.return_value = {'ndi_id': ['doc1', 'doc2'], 'api_id': ['api1', 'api2']}

            two_way_sync(mock_dataset, verbose=False)

            # Should not upload or download anything
            mock_upload.assert_not_called()
            mock_download.assert_not_called()
            # Should still update index
            mock_update_index.assert_called_once()


class TestMirrorToRemote:
    """Tests for mirror_to_remote function."""

    def test_mirror_to_remote_upload(self):
        """Test mirroring to remote with uploads."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.mirror_to_remote.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.mirror_to_remote.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.mirror_to_remote.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.mirror_to_remote.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.mirror_to_remote.delete_remote_documents') as mock_delete, \
             patch('ndi.cloud.sync.mirror_to_remote.upload_files_for_dataset_documents') as mock_upload_files, \
             patch('ndi.cloud.sync.mirror_to_remote.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Local has doc1, doc2; Remote has doc2, doc3
            mock_list_local.return_value = ([Mock(), Mock()], ['doc1', 'doc2'])
            mock_list_remote.side_effect = [
                {'ndi_id': ['doc2', 'doc3'], 'api_id': ['api2', 'api3']},  # Initial
                {'ndi_id': ['doc1', 'doc2', 'doc3'], 'api_id': ['api1', 'api2', 'api3']},  # After upload
                {'ndi_id': ['doc1', 'doc2'], 'api_id': ['api1', 'api2']}  # After delete
            ]

            mirror_to_remote(mock_dataset, verbose=False, sync_files=False)

            # Should upload doc1
            mock_upload.assert_called()
            # Should delete doc3 from remote
            mock_delete.assert_called()

    def test_mirror_to_remote_delete_only(self):
        """Test mirroring to remote with only deletions."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.mirror_to_remote.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.mirror_to_remote.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.mirror_to_remote.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.mirror_to_remote.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.mirror_to_remote.delete_remote_documents') as mock_delete, \
             patch('ndi.cloud.sync.mirror_to_remote.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Local has doc1; Remote has doc1, doc2
            mock_list_local.return_value = ([Mock()], ['doc1'])
            mock_list_remote.side_effect = [
                {'ndi_id': ['doc1', 'doc2'], 'api_id': ['api1', 'api2']},  # Initial/After upload
                {'ndi_id': ['doc1'], 'api_id': ['api1']}  # Final
            ]

            mirror_to_remote(mock_dataset, verbose=False)

            # Should not upload anything
            mock_upload.assert_not_called()
            # Should delete doc2
            mock_delete.assert_called()


class TestMirrorFromRemote:
    """Tests for mirror_from_remote function."""

    def test_mirror_from_remote_download(self):
        """Test mirroring from remote with downloads."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.mirror_from_remote.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.mirror_from_remote.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.mirror_from_remote.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.mirror_from_remote.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.mirror_from_remote.delete_local_documents') as mock_delete, \
             patch('ndi.cloud.sync.mirror_from_remote.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Local has doc1, doc2; Remote has doc2, doc3
            mock_list_local.side_effect = [
                ([Mock(), Mock()], ['doc1', 'doc2']),  # Initial
                ([Mock(), Mock(), Mock()], ['doc1', 'doc2', 'doc3']),  # After download
                ([Mock(), Mock()], ['doc2', 'doc3'])  # After delete
            ]
            mock_list_remote.return_value = {'ndi_id': ['doc2', 'doc3'], 'api_id': ['api2', 'api3']}

            mirror_from_remote(mock_dataset, verbose=False)

            # Should download doc3
            mock_download.assert_called()
            # Should delete doc1 locally
            mock_delete.assert_called()

    def test_mirror_from_remote_delete_only(self):
        """Test mirroring from remote with only deletions."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.mirror_from_remote.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.mirror_from_remote.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.mirror_from_remote.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.mirror_from_remote.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.mirror_from_remote.delete_local_documents') as mock_delete, \
             patch('ndi.cloud.sync.mirror_from_remote.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Local has doc1, doc2; Remote has doc2
            mock_list_local.side_effect = [
                ([Mock(), Mock()], ['doc1', 'doc2']),  # Initial
                ([Mock(), Mock()], ['doc1', 'doc2']),  # After download (no change)
                ([Mock()], ['doc2'])  # After delete
            ]
            mock_list_remote.return_value = {'ndi_id': ['doc2'], 'api_id': ['api2']}

            mirror_from_remote(mock_dataset, verbose=False)

            # Should not download anything
            mock_download.assert_not_called()
            # Should delete doc1
            mock_delete.assert_called()


class TestUploadNew:
    """Tests for upload_new function."""

    def test_upload_new_documents(self):
        """Test uploading new documents added since last sync."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.upload_new.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.upload_new.read_sync_index') as mock_read_index, \
             patch('ndi.cloud.sync.upload_new.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.upload_new.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.upload_new.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.upload_new.upload_files_for_dataset_documents') as mock_upload_files, \
             patch('ndi.cloud.sync.upload_new.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Last sync had doc1; now we have doc1, doc2
            mock_read_index.return_value = {'localDocumentIdsLastSync': ['doc1']}
            mock_list_local.return_value = ([Mock(), Mock()], ['doc1', 'doc2'])
            mock_list_remote.return_value = {'ndi_id': ['doc1'], 'api_id': ['api1']}

            upload_new(mock_dataset, verbose=False, sync_files=False)

            # Should upload doc2
            assert mock_upload.called
            uploaded_docs = mock_upload.call_args[0][1]
            assert len(uploaded_docs) == 1

    def test_upload_new_no_changes(self):
        """Test upload_new when no new documents added."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.upload_new.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.upload_new.read_sync_index') as mock_read_index, \
             patch('ndi.cloud.sync.upload_new.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.upload_new.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.upload_new.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.upload_new.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Same documents as last sync
            mock_read_index.return_value = {'localDocumentIdsLastSync': ['doc1', 'doc2']}
            mock_list_local.return_value = ([Mock(), Mock()], ['doc1', 'doc2'])
            mock_list_remote.return_value = {'ndi_id': ['doc1', 'doc2'], 'api_id': ['api1', 'api2']}

            upload_new(mock_dataset, verbose=False)

            # Should not upload anything
            mock_upload.assert_not_called()

    def test_upload_new_first_sync(self):
        """Test upload_new when no previous sync index exists."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.upload_new.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.upload_new.read_sync_index') as mock_read_index, \
             patch('ndi.cloud.sync.upload_new.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.upload_new.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.upload_new.upload_document_collection') as mock_upload, \
             patch('ndi.cloud.sync.upload_new.upload_files_for_dataset_documents') as mock_upload_files, \
             patch('ndi.cloud.sync.upload_new.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # No previous sync
            mock_read_index.return_value = None
            mock_list_local.return_value = ([Mock()], ['doc1'])
            mock_list_remote.return_value = {'ndi_id': [], 'api_id': []}

            upload_new(mock_dataset, verbose=False, sync_files=False)

            # Should upload all local documents
            mock_upload.assert_called()


class TestDownloadNew:
    """Tests for download_new function."""

    def test_download_new_documents(self):
        """Test downloading new documents added to remote since last sync."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.download_new.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.download_new.read_sync_index') as mock_read_index, \
             patch('ndi.cloud.sync.download_new.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.download_new.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.download_new.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.download_new.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Last sync had doc1; now remote has doc1, doc2
            mock_read_index.return_value = {'remoteDocumentIdsLastSync': ['doc1']}
            mock_list_local.side_effect = [
                ([Mock()], ['doc1', 'doc2'])  # After download
            ]
            mock_list_remote.return_value = {'ndi_id': ['doc1', 'doc2'], 'api_id': ['api1', 'api2']}

            download_new(mock_dataset, verbose=False)

            # Should download doc2
            assert mock_download.called
            downloaded_ids = mock_download.call_args[0][1]
            assert 'api2' in downloaded_ids

    def test_download_new_no_changes(self):
        """Test download_new when no new documents on remote."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.download_new.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.download_new.read_sync_index') as mock_read_index, \
             patch('ndi.cloud.sync.download_new.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.download_new.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.download_new.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.download_new.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # Same documents as last sync
            mock_read_index.return_value = {'remoteDocumentIdsLastSync': ['doc1', 'doc2']}
            mock_list_local.return_value = ([Mock(), Mock()], ['doc1', 'doc2'])
            mock_list_remote.return_value = {'ndi_id': ['doc1', 'doc2'], 'api_id': ['api1', 'api2']}

            download_new(mock_dataset, verbose=False)

            # Should not download anything
            mock_download.assert_not_called()

    def test_download_new_first_sync(self):
        """Test download_new when no previous sync index exists."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        with patch('ndi.cloud.sync.download_new.get_cloud_dataset_id_for_local_dataset') as mock_get_id, \
             patch('ndi.cloud.sync.download_new.read_sync_index') as mock_read_index, \
             patch('ndi.cloud.sync.download_new.list_local_documents') as mock_list_local, \
             patch('ndi.cloud.sync.download_new.list_remote_document_ids') as mock_list_remote, \
             patch('ndi.cloud.sync.download_new.download_ndi_documents') as mock_download, \
             patch('ndi.cloud.sync.download_new.update_sync_index') as mock_update_index:

            mock_get_id.return_value = 'cloud_dataset_123'
            # No previous sync
            mock_read_index.return_value = None
            mock_list_local.return_value = ([Mock()], ['doc1'])
            mock_list_remote.return_value = {'ndi_id': ['doc1'], 'api_id': ['api1']}

            download_new(mock_dataset, verbose=False)

            # Should download all remote documents
            mock_download.assert_called()


@pytest.fixture
def mock_dataset():
    """Fixture providing a mock dataset."""
    dataset = Mock()
    dataset.path = '/tmp/test_dataset'
    dataset.database_search = Mock(return_value=[])
    return dataset


@pytest.fixture
def sync_options():
    """Fixture providing default sync options."""
    return SyncOptions(verbose=False, sync_files=False)


def test_integration_sync_options_with_sync_mode(mock_dataset):
    """Integration test: use SyncOptions with SyncMode."""
    opts = SyncOptions(verbose=False, dry_run=True)

    with patch('ndi.cloud.sync.sync_mode.upload_new') as mock_upload_new:
        SyncMode.UPLOAD_NEW.execute(mock_dataset, opts)

        # Should have called upload_new with options
        mock_upload_new.assert_called_once()
        call_kwargs = mock_upload_new.call_args[1]
        assert call_kwargs['verbose'] is False
        assert call_kwargs['dry_run'] is True


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
