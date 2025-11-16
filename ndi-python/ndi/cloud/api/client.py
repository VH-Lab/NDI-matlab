"""
NDI Cloud Client - Main client class for NDI Cloud API.

This module provides the CloudClient class that manages authentication
and provides a high-level interface to all NDI Cloud operations.
"""

from typing import Dict, Any, Optional, Tuple, List
import logging
from . import auth, datasets, documents, files, users


class CloudClient:
    """
    Main client for interacting with the NDI Cloud API.

    This class manages authentication state and provides convenient methods
    for all cloud operations.

    Attributes:
        token (str): Authentication token (None if not logged in)
        user_info (dict): User information from login
        organization_id (str): Current organization ID

    Example:
        >>> client = CloudClient()
        >>> client.login('user@example.com', 'password')
        >>> datasets = client.list_datasets()
        >>> client.logout()
    """

    def __init__(self, token: Optional[str] = None):
        """
        Initialize Cloud Client.

        Args:
            token: Optional pre-existing authentication token
        """
        self.token = token
        self.user_info: Optional[Dict[str, Any]] = None
        self.organization_id: Optional[str] = None

    # ==================== Authentication ====================

    def login(self, email: str, password: str) -> bool:
        """
        Login to NDI Cloud.

        Args:
            email: User email address
            password: User password

        Returns:
            True if login successful, False otherwise

        Example:
            >>> client = CloudClient()
            >>> success = client.login('user@example.com', 'password')
            >>> if success:
            ...     print(f"Logged in as {client.user_info['email']}")
        """
        success, answer, response, url = auth.login(email, password)

        if success:
            self.token = answer['token']
            self.user_info = answer.get('user', {})

            # Extract organization ID if available
            if 'organizations' in self.user_info and self.user_info['organizations']:
                self.organization_id = self.user_info['organizations'][0].get('id')

            logging.info(f"Successfully logged in as {email}")
            return True
        else:
            logging.error(f"Login failed: {answer}")
            return False

    def logout(self) -> bool:
        """
        Logout from NDI Cloud.

        Returns:
            True if logout successful, False otherwise
        """
        if not self.token:
            logging.warning("Not logged in")
            return False

        success, answer, response, url = auth.logout(self.token)

        if success:
            self.token = None
            self.user_info = None
            self.organization_id = None
            logging.info("Successfully logged out")
            return True
        else:
            logging.error(f"Logout failed: {answer}")
            return False

    def is_authenticated(self) -> bool:
        """Check if client is authenticated."""
        return self.token is not None

    # ==================== Datasets ====================

    def get_dataset(self, dataset_id: str) -> Optional[Dict[str, Any]]:
        """
        Get a dataset by ID.

        Args:
            dataset_id: Dataset ID

        Returns:
            Dataset data or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = datasets.get_dataset(self.token, dataset_id)
        return answer if success else None

    def list_datasets(self) -> Optional[List[Dict[str, Any]]]:
        """
        List all datasets for current organization.

        Returns:
            List of datasets or None if failed
        """
        if not self.token or not self.organization_id:
            logging.error("Not authenticated or no organization")
            return None

        success, answer, response, url = datasets.list_datasets(self.token, self.organization_id)
        return answer if success else None

    def create_dataset(self, dataset_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Create a new dataset.

        Args:
            dataset_data: Dataset metadata (name, description, etc.)

        Returns:
            Created dataset data or None if failed
        """
        if not self.token or not self.organization_id:
            logging.error("Not authenticated or no organization")
            return None

        success, answer, response, url = datasets.create_dataset(
            self.token, self.organization_id, dataset_data
        )
        return answer if success else None

    def update_dataset(self, dataset_id: str, dataset_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Update an existing dataset.

        Args:
            dataset_id: Dataset ID
            dataset_data: Updated dataset metadata

        Returns:
            Updated dataset data or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = datasets.update_dataset(
            self.token, dataset_id, dataset_data
        )
        return answer if success else None

    def delete_dataset(self, dataset_id: str) -> bool:
        """
        Delete a dataset.

        Args:
            dataset_id: Dataset ID

        Returns:
            True if successful, False otherwise
        """
        if not self.token:
            logging.error("Not authenticated")
            return False

        success, answer, response, url = datasets.delete_dataset(self.token, dataset_id)
        return success

    def publish_dataset(self, dataset_id: str) -> bool:
        """
        Publish a dataset.

        Args:
            dataset_id: Dataset ID

        Returns:
            True if successful, False otherwise
        """
        if not self.token:
            logging.error("Not authenticated")
            return False

        success, answer, response, url = datasets.publish_dataset(self.token, dataset_id)
        return success

    def unpublish_dataset(self, dataset_id: str) -> bool:
        """
        Unpublish a dataset.

        Args:
            dataset_id: Dataset ID

        Returns:
            True if successful, False otherwise
        """
        if not self.token:
            logging.error("Not authenticated")
            return False

        success, answer, response, url = datasets.unpublish_dataset(self.token, dataset_id)
        return success

    def get_published_datasets(self, page: int = 1, page_size: int = 20) -> Optional[List[Dict[str, Any]]]:
        """
        Get published datasets.

        Args:
            page: Page number
            page_size: Number of items per page

        Returns:
            List of published datasets or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = datasets.get_published(self.token, page, page_size)
        return answer if success else None

    def get_unpublished_datasets(self, page: int = 1, page_size: int = 20) -> Optional[List[Dict[str, Any]]]:
        """
        Get unpublished datasets.

        Args:
            page: Page number
            page_size: Number of items per page

        Returns:
            List of unpublished datasets or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = datasets.get_unpublished(self.token, page, page_size)
        return answer if success else None

    # ==================== Documents ====================

    def get_document(self, dataset_id: str, document_id: str) -> Optional[Dict[str, Any]]:
        """
        Get a document from a dataset.

        Args:
            dataset_id: Dataset ID
            document_id: Document ID

        Returns:
            Document data or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = documents.get_document(self.token, dataset_id, document_id)
        return answer if success else None

    def list_documents(self, dataset_id: str, page: int = 1, page_size: int = 20) -> Optional[List[Dict[str, Any]]]:
        """
        List documents in a dataset.

        Args:
            dataset_id: Dataset ID
            page: Page number
            page_size: Number of items per page

        Returns:
            List of documents or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = documents.list_dataset_documents(
            self.token, dataset_id, page, page_size
        )
        return answer if success else None

    def add_document(self, dataset_id: str, document_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Add a document to a dataset.

        Args:
            dataset_id: Dataset ID
            document_data: Document data

        Returns:
            Created document data or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = documents.add_document(
            self.token, dataset_id, document_data
        )
        return answer if success else None

    def update_document(self, dataset_id: str, document_id: str, document_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Update a document in a dataset.

        Args:
            dataset_id: Dataset ID
            document_id: Document ID
            document_data: Updated document data

        Returns:
            Updated document data or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = documents.update_document(
            self.token, dataset_id, document_id, document_data
        )
        return answer if success else None

    def delete_document(self, dataset_id: str, document_id: str) -> bool:
        """
        Delete a document from a dataset.

        Args:
            dataset_id: Dataset ID
            document_id: Document ID

        Returns:
            True if successful, False otherwise
        """
        if not self.token:
            logging.error("Not authenticated")
            return False

        success, answer, response, url = documents.delete_document(
            self.token, dataset_id, document_id
        )
        return success

    def document_count(self, dataset_id: str) -> Optional[int]:
        """
        Get document count for a dataset.

        Args:
            dataset_id: Dataset ID

        Returns:
            Document count or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = documents.document_count(self.token, dataset_id)
        return answer.get('count') if success else None

    # ==================== Files ====================

    def get_file(self, dataset_id: str, file_uid: str) -> Optional[bytes]:
        """
        Get a file from a dataset.

        Args:
            dataset_id: Dataset ID
            file_uid: File UID

        Returns:
            File content (bytes) or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = files.get_file(self.token, dataset_id, file_uid)
        return answer if success else None

    def get_file_details(self, dataset_id: str, file_uid: str) -> Optional[Dict[str, Any]]:
        """
        Get file details/metadata.

        Args:
            dataset_id: Dataset ID
            file_uid: File UID

        Returns:
            File metadata or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = files.get_file_details(self.token, dataset_id, file_uid)
        return answer if success else None

    def get_file_upload_url(self, dataset_id: str, file_uid: str) -> Optional[str]:
        """
        Get a pre-signed URL for file upload.

        Args:
            dataset_id: Dataset ID
            file_uid: File UID

        Returns:
            Upload URL or None if failed
        """
        if not self.token or not self.organization_id:
            logging.error("Not authenticated or no organization")
            return None

        success, answer, response, url = files.get_file_upload_url(
            self.token, self.organization_id, dataset_id, file_uid
        )
        return answer.get('uploadUrl') if success else None

    def list_files(self, dataset_id: str) -> Optional[List[Dict[str, Any]]]:
        """
        List files in a dataset.

        Args:
            dataset_id: Dataset ID

        Returns:
            List of files or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = files.list_files(self.token, dataset_id)
        return answer if success else None

    # ==================== Users ====================

    def get_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get user information.

        Args:
            user_id: User ID

        Returns:
            User data or None if failed
        """
        if not self.token:
            logging.error("Not authenticated")
            return None

        success, answer, response, url = users.get_user(self.token, user_id)
        return answer if success else None

    def __repr__(self) -> str:
        """String representation of CloudClient."""
        auth_status = "authenticated" if self.token else "not authenticated"
        org = f", org={self.organization_id}" if self.organization_id else ""
        return f"CloudClient({auth_status}{org})"
