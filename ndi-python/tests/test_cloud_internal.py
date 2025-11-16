"""
Comprehensive tests for cloud internal utilities.

Tests JWT decoding (PyJWT and base64 fallback), get_cloud_dataset_id_for_local_dataset,
token expiration checking, and get_uploaded_file_ids.
"""

import pytest
import base64
import json
from datetime import datetime, timezone, timedelta
from unittest.mock import Mock, patch, MagicMock

from ndi.cloud.internal.decode_jwt import decode_jwt
from ndi.cloud.internal.get_cloud_dataset_id_for_local_dataset import get_cloud_dataset_id_for_local_dataset
from ndi.cloud.internal.get_token_expiration import get_token_expiration
from ndi.cloud.internal.get_uploaded_file_ids import get_uploaded_file_ids


class TestDecodeJWT:
    """Tests for JWT decoding functions."""

    def create_test_jwt(self, payload):
        """Helper to create a test JWT token."""
        # Create header
        header = {"alg": "HS256", "typ": "JWT"}
        header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip('=')

        # Create payload
        payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')

        # Create signature (fake - we're not verifying)
        signature = base64.urlsafe_b64encode(b'fake_signature').decode().rstrip('=')

        return f"{header_b64}.{payload_b64}.{signature}"

    def test_decode_jwt_with_pyjwt(self):
        """Test JWT decoding using PyJWT library."""
        payload = {"sub": "user123", "exp": 1234567890, "name": "Test User"}
        token = self.create_test_jwt(payload)

        try:
            import jwt
            # If PyJWT is available, test with it
            decoded = decode_jwt(token)
            assert decoded["sub"] == "user123"
            assert decoded["name"] == "Test User"
        except ImportError:
            # PyJWT not available, skip this test
            pytest.skip("PyJWT not installed")

    def test_decode_jwt_fallback(self):
        """Test JWT decoding using base64 fallback."""
        payload = {"sub": "user123", "exp": 1234567890, "name": "Test User"}
        token = self.create_test_jwt(payload)

        # Mock PyJWT import to force fallback
        with patch.dict('sys.modules', {'jwt': None}):
            decoded = decode_jwt(token)
            assert decoded["sub"] == "user123"
            assert decoded["name"] == "Test User"
            assert decoded["exp"] == 1234567890

    def test_decode_jwt_invalid_format(self):
        """Test error handling for invalid JWT format."""
        # Token with wrong number of parts
        with pytest.raises(ValueError, match="Invalid JWT format"):
            decode_jwt("invalid.token")

        with pytest.raises(ValueError, match="Invalid JWT format"):
            decode_jwt("too.many.parts.here")

    def test_decode_jwt_invalid_base64(self):
        """Test error handling for invalid base64 encoding."""
        # Create malformed token with invalid base64
        invalid_token = "eyJhbGc.!!!invalid_base64!!!.signature"

        with pytest.raises(ValueError, match="Failed to decode JWT"):
            decode_jwt(invalid_token)

    def test_decode_jwt_invalid_json(self):
        """Test error handling for invalid JSON in payload."""
        # Create token with invalid JSON
        header_b64 = base64.urlsafe_b64encode(b'{"alg":"HS256"}').decode().rstrip('=')
        payload_b64 = base64.urlsafe_b64encode(b'{invalid json}').decode().rstrip('=')
        signature = base64.urlsafe_b64encode(b'sig').decode().rstrip('=')

        token = f"{header_b64}.{payload_b64}.{signature}"

        with pytest.raises(ValueError, match="not valid JSON"):
            decode_jwt(token)

    def test_decode_jwt_non_string_input(self):
        """Test error handling for non-string input."""
        with pytest.raises(ValueError, match="must be a string"):
            decode_jwt(12345)

        with pytest.raises(ValueError, match="must be a string"):
            decode_jwt(None)

    def test_decode_jwt_with_padding(self):
        """Test decoding JWT that needs padding."""
        # Create payload that will result in base64 needing padding
        payload = {"data": "x"}  # Short payload
        token = self.create_test_jwt(payload)

        decoded = decode_jwt(token)
        assert decoded["data"] == "x"

    def test_decode_jwt_complex_payload(self):
        """Test decoding JWT with complex payload."""
        payload = {
            "sub": "user123",
            "exp": 1234567890,
            "iat": 1234567800,
            "roles": ["admin", "user"],
            "metadata": {
                "dataset_id": "abc123",
                "permissions": ["read", "write"]
            }
        }
        token = self.create_test_jwt(payload)

        decoded = decode_jwt(token)
        assert decoded["sub"] == "user123"
        assert decoded["roles"] == ["admin", "user"]
        assert decoded["metadata"]["dataset_id"] == "abc123"


class TestGetCloudDatasetIdForLocalDataset:
    """Tests for get_cloud_dataset_id_for_local_dataset function."""

    def test_get_cloud_dataset_id_found(self):
        """Test retrieving cloud dataset ID when it exists."""
        mock_dataset = Mock()
        mock_document = Mock()
        mock_document.document_properties = {
            'dataset_remote': {'dataset_id': 'cloud_dataset_123'}
        }

        mock_dataset.database_search = Mock(return_value=[mock_document])

        cloud_id, cloud_doc = get_cloud_dataset_id_for_local_dataset(mock_dataset)

        assert cloud_id == 'cloud_dataset_123'
        assert cloud_doc == [mock_document]

    def test_get_cloud_dataset_id_not_found(self):
        """Test when no cloud dataset ID document exists."""
        mock_dataset = Mock()
        mock_dataset.database_search = Mock(return_value=[])

        cloud_id, cloud_doc = get_cloud_dataset_id_for_local_dataset(mock_dataset)

        assert cloud_id == ''
        assert cloud_doc == []

    def test_get_cloud_dataset_id_multiple_found(self):
        """Test error when multiple cloud dataset ID documents exist."""
        mock_dataset = Mock()
        mock_dataset.path = '/tmp/test_dataset'

        mock_doc1 = Mock()
        mock_doc2 = Mock()
        mock_dataset.database_search = Mock(return_value=[mock_doc1, mock_doc2])

        with pytest.raises(RuntimeError, match="more than one remote cloudDatasetId"):
            get_cloud_dataset_id_for_local_dataset(mock_dataset)

    def test_get_cloud_dataset_id_query_format(self):
        """Test that correct query is used."""
        mock_dataset = Mock()
        mock_dataset.database_search = Mock(return_value=[])

        with patch('ndi.cloud.internal.get_cloud_dataset_id_for_local_dataset.query') as mock_query:
            mock_query.return_value = Mock()

            get_cloud_dataset_id_for_local_dataset(mock_dataset)

            # Should query for 'dataset_remote' documents
            mock_query.assert_called_once_with('', isa='dataset_remote')


class TestGetTokenExpiration:
    """Tests for token expiration extraction."""

    def create_jwt_with_expiration(self, exp_timestamp):
        """Helper to create JWT with specific expiration."""
        payload = {"sub": "user123", "exp": exp_timestamp}

        header = {"alg": "HS256", "typ": "JWT"}
        header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip('=')
        payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')
        signature = base64.urlsafe_b64encode(b'sig').decode().rstrip('=')

        return f"{header_b64}.{payload_b64}.{signature}"

    def test_get_token_expiration_valid(self):
        """Test extracting expiration from valid token."""
        # Set expiration to 1 hour from now
        exp_timestamp = int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
        token = self.create_jwt_with_expiration(exp_timestamp)

        exp_time = get_token_expiration(token)

        assert isinstance(exp_time, datetime)
        assert exp_time.tzinfo is not None  # Should have timezone info

    def test_get_token_expiration_past(self):
        """Test token with past expiration."""
        # Set expiration to 1 hour ago
        exp_timestamp = int((datetime.now(timezone.utc) - timedelta(hours=1)).timestamp())
        token = self.create_jwt_with_expiration(exp_timestamp)

        exp_time = get_token_expiration(token)

        # Should still parse even if expired
        assert exp_time < datetime.now(timezone.utc)

    def test_get_token_expiration_missing_exp(self):
        """Test error when token has no 'exp' claim."""
        payload = {"sub": "user123"}  # No 'exp' field

        header = {"alg": "HS256"}
        header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip('=')
        payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')
        signature = base64.urlsafe_b64encode(b'sig').decode().rstrip('=')

        token = f"{header_b64}.{payload_b64}.{signature}"

        with pytest.raises(KeyError, match="exp"):
            get_token_expiration(token)

    def test_get_token_expiration_timezone_conversion(self):
        """Test that expiration time is converted to local timezone."""
        exp_timestamp = int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
        token = self.create_jwt_with_expiration(exp_timestamp)

        exp_time = get_token_expiration(token)

        # Should have timezone info (local timezone)
        assert exp_time.tzinfo is not None
        # Should be close to the expected time (within a few seconds)
        expected = datetime.fromtimestamp(exp_timestamp, tz=timezone.utc).astimezone()
        assert abs((exp_time - expected).total_seconds()) < 1


class TestGetUploadedFileIds:
    """Tests for get_uploaded_file_ids function."""

    def test_get_uploaded_file_ids_success(self):
        """Test retrieving uploaded file IDs successfully."""
        dataset_id = "test_dataset_123"

        mock_datasets = [
            {
                'id': 'other_dataset',
                'files': [{'uid': 'file1', 'uploaded': True}]
            },
            {
                'id': dataset_id,
                'files': [
                    {'uid': 'file_a', 'uploaded': True},
                    {'uid': 'file_b', 'uploaded': False},
                    {'uid': 'file_c', 'uploaded': True}
                ]
            }
        ]

        with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
            mock_list.return_value = (True, None, mock_datasets)

            file_ids = get_uploaded_file_ids(dataset_id)

            assert len(file_ids) == 2
            assert 'file_a' in file_ids
            assert 'file_c' in file_ids
            assert 'file_b' not in file_ids

    def test_get_uploaded_file_ids_no_files(self):
        """Test when dataset has no files."""
        dataset_id = "empty_dataset"

        mock_datasets = [
            {
                'id': dataset_id,
                'files': []
            }
        ]

        with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
            mock_list.return_value = (True, None, mock_datasets)

            file_ids = get_uploaded_file_ids(dataset_id)

            assert file_ids == []

    def test_get_uploaded_file_ids_dataset_not_found(self):
        """Test error when dataset is not found."""
        dataset_id = "nonexistent_dataset"

        mock_datasets = [
            {'id': 'other_dataset', 'files': []}
        ]

        with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
            mock_list.return_value = (True, None, mock_datasets)

            with pytest.raises(RuntimeError, match="No dataset found"):
                get_uploaded_file_ids(dataset_id)

    def test_get_uploaded_file_ids_api_failure(self):
        """Test error when API call fails."""
        dataset_id = "test_dataset"

        with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
            mock_list.return_value = (False, None, [])

            with pytest.raises(RuntimeError, match="Failed to list datasets"):
                get_uploaded_file_ids(dataset_id)

    def test_get_uploaded_file_ids_no_files_field(self):
        """Test when dataset has no 'files' field."""
        dataset_id = "test_dataset"

        mock_datasets = [
            {'id': dataset_id}  # No 'files' field
        ]

        with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
            mock_list.return_value = (True, None, mock_datasets)

            file_ids = get_uploaded_file_ids(dataset_id)

            assert file_ids == []

    def test_get_uploaded_file_ids_exception_handling(self):
        """Test exception handling during retrieval."""
        dataset_id = "test_dataset"

        with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
            mock_list.side_effect = Exception("Network error")

            with pytest.raises(RuntimeError, match="Error retrieving dataset"):
                get_uploaded_file_ids(dataset_id)


@pytest.fixture
def sample_jwt_payload():
    """Fixture providing a sample JWT payload."""
    return {
        "sub": "user_12345",
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
        "iat": int(datetime.now(timezone.utc).timestamp()),
        "name": "Test User",
        "email": "test@example.com",
        "roles": ["user", "researcher"]
    }


@pytest.fixture
def mock_dataset_with_cloud_id():
    """Fixture providing a mock dataset with cloud ID."""
    dataset = Mock()
    dataset.path = '/tmp/test_dataset'

    doc = Mock()
    doc.document_properties = {
        'dataset_remote': {'dataset_id': 'cloud_123'}
    }
    dataset.database_search = Mock(return_value=[doc])

    return dataset


def test_integration_jwt_decode_and_expiration(sample_jwt_payload):
    """Integration test: decode JWT and extract expiration."""
    # Create JWT
    header = {"alg": "HS256", "typ": "JWT"}
    header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip('=')
    payload_b64 = base64.urlsafe_b64encode(json.dumps(sample_jwt_payload).encode()).decode().rstrip('=')
    signature = base64.urlsafe_b64encode(b'sig').decode().rstrip('=')

    token = f"{header_b64}.{payload_b64}.{signature}"

    # Decode token
    decoded = decode_jwt(token)
    assert decoded["sub"] == "user_12345"
    assert decoded["name"] == "Test User"

    # Extract expiration
    exp_time = get_token_expiration(token)
    assert isinstance(exp_time, datetime)

    # Expiration should be in the future
    assert exp_time > datetime.now(exp_time.tzinfo)


def test_integration_get_cloud_id_and_files(mock_dataset_with_cloud_id):
    """Integration test: get cloud dataset ID and file IDs."""
    # Get cloud dataset ID
    cloud_id, cloud_doc = get_cloud_dataset_id_for_local_dataset(mock_dataset_with_cloud_id)
    assert cloud_id == 'cloud_123'

    # Mock file retrieval
    mock_datasets = [
        {
            'id': cloud_id,
            'files': [
                {'uid': 'file1', 'uploaded': True},
                {'uid': 'file2', 'uploaded': True}
            ]
        }
    ]

    with patch('ndi.cloud.internal.get_uploaded_file_ids.list_datasets') as mock_list:
        mock_list.return_value = (True, None, mock_datasets)

        file_ids = get_uploaded_file_ids(cloud_id)
        assert len(file_ids) == 2
        assert 'file1' in file_ids
        assert 'file2' in file_ids


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
