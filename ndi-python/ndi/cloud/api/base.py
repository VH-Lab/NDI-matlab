"""
NDI Cloud API Base - Abstract base class for all API calls.

This module provides the base class that all NDI Cloud API calls inherit from.
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Tuple
import os


class CloudAPICall(ABC):
    """
    Abstract base class for all NDI Cloud API calls.

    Ensures that all API call implementations have an 'execute' method
    with a consistent signature for handling success and failure.

    Attributes:
        cloud_organization_id (str): Organization ID for the API call
        cloud_dataset_id (str): Dataset ID for the API call
        cloud_file_id (str): File ID for the API call
        cloud_user_id (str): User ID for the API call
        cloud_document_id (str): Document ID for the API call
        page (int): Page number for paginated results
        page_size (int): Number of items per page
        endpoint_name (str): Name of the API endpoint
    """

    def __init__(self):
        """Initialize API call with common parameters."""
        self.cloud_organization_id: Optional[str] = None
        self.cloud_dataset_id: Optional[str] = None
        self.cloud_file_id: Optional[str] = None
        self.cloud_user_id: Optional[str] = None
        self.cloud_document_id: Optional[str] = None
        self.page: Optional[int] = None
        self.page_size: Optional[int] = None
        self.endpoint_name: Optional[str] = None

    @abstractmethod
    def execute(self) -> Tuple[bool, Any, Any, str]:
        """
        Perform the API call.

        Returns:
            A tuple containing:
                - success (bool): True if the call succeeded, False otherwise
                - answer (Any): The data payload from the API (empty on failure)
                - response (requests.Response): The full HTTP response object
                - api_url (str): The URL that was called

        Raises:
            NotImplementedError: If not implemented by subclass
        """
        pass

    @staticmethod
    def get_api_url(endpoint_name: str, **kwargs) -> str:
        """
        Get the URL for a named API endpoint.

        Args:
            endpoint_name: Name of the endpoint (e.g., 'login', 'get_dataset')
            **kwargs: Parameters for URL path substitution (dataset_id, user_id, etc.)

        Returns:
            The complete URL for the endpoint

        Raises:
            ValueError: If required parameters are missing or environment is invalid

        Example:
            >>> url = CloudAPICall.get_api_url('get_dataset', dataset_id='abc123')
            >>> print(url)
            https://api.ndi-cloud.com/v1/datasets/abc123
        """
        # Get API environment
        api_environment = os.getenv('CLOUD_API_ENVIRONMENT', 'prod')

        if api_environment == 'prod':
            api_base_url = "https://api.ndi-cloud.com/v1"
        elif api_environment == 'dev':
            api_base_url = "https://dev-api.ndi-cloud.com/v1"
        else:
            raise ValueError(
                f"Expected value for cloud api environment to be 'prod' or 'dev', "
                f"but got '{api_environment}' instead."
            )

        # Endpoint map
        endpoint_map = {
            'login': '/auth/login',
            'logout': '/auth/logout',
            'resend_confirmation': '/auth/confirmation/resend',
            'verify_user': '/auth/verify',
            'change_password': '/auth/password',
            'reset_password': '/auth/password/forgot',
            'set_new_password': '/auth/password/confirm',
            'create_user': '/users',
            'get_user': '/users/{user_id}',
            'get_dataset': '/datasets/{dataset_id}',
            'update_dataset': '/datasets/{dataset_id}',
            'delete_dataset': '/datasets/{dataset_id}',
            'list_datasets': '/organizations/{organization_id}/datasets',
            'create_dataset': '/organizations/{organization_id}/datasets',
            'get_published': '/datasets/published?page={page}&pageSize={page_size}',
            'get_unpublished': '/datasets/unpublished?page={page}&pageSize={page_size}',
            'get_file_upload_url': '/datasets/{organization_id}/{dataset_id}/files/{file_uid}',
            'get_file_collection_upload_url': '/datasets/{organization_id}/{dataset_id}/files/bulk',
            'get_file_details': '/datasets/{dataset_id}/files/{file_uid}/detail',
            'create_dataset_branch': '/datasets/{dataset_id}/branch',
            'get_branches': '/datasets/{dataset_id}/branches',
            'submit_dataset': '/datasets/{dataset_id}/submit',
            'publish_dataset': '/datasets/{dataset_id}/publish',
            'unpublish_dataset': '/datasets/{dataset_id}/unpublish',
            'document_count': '/datasets/{dataset_id}/document-count',
            'get_document': '/datasets/{dataset_id}/documents/{document_id}',
            'update_document': '/datasets/{dataset_id}/documents/{document_id}',
            'delete_document': '/datasets/{dataset_id}/documents/{document_id}',
            'bulk_delete_documents': '/datasets/{dataset_id}/documents/bulk-delete',
            'bulk_upload_documents': '/datasets/{dataset_id}/documents/bulk-upload',
            'bulk_download_documents': '/datasets/{dataset_id}/documents/bulk-download',
            'list_dataset_documents': '/datasets/{dataset_id}/documents?page={page}&pageSize={page_size}',
            'add_document': '/datasets/{dataset_id}/documents',
            'search_datasets': '/datasets/search',
            'list_files': '/datasets/{dataset_id}/files',
            'get_file': '/datasets/{dataset_id}/files/{file_uid}',
            'put_files': '/datasets/{organization_id}/{dataset_id}/files',
        }

        if endpoint_name not in endpoint_map:
            raise ValueError(f"Unknown endpoint: {endpoint_name}")

        endpoint_path = endpoint_map[endpoint_name]

        # Replace path parameters
        # Find all {param} placeholders
        import re
        placeholders = re.findall(r'\{([^}]+)\}', endpoint_path)

        for placeholder in placeholders:
            if placeholder not in kwargs:
                raise ValueError(
                    f"'{placeholder}' is a required parameter for the '{endpoint_name}' endpoint"
                )

            value = kwargs[placeholder]
            if isinstance(value, (int, float)):
                value = str(int(value))
            elif not isinstance(value, str):
                value = str(value)

            if not value:
                raise ValueError(
                    f"'{placeholder}' parameter cannot be empty for the '{endpoint_name}' endpoint"
                )

            endpoint_path = endpoint_path.replace(f'{{{placeholder}}}', value)

        return api_base_url + endpoint_path

    def __repr__(self) -> str:
        """String representation of API call."""
        return f"{self.__class__.__name__}(endpoint='{self.endpoint_name}')"
