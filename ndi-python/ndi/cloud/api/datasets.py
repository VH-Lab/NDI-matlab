"""
NDI Cloud API Datasets - Dataset management operations.

This module provides dataset-related API calls for the NDI Cloud.
"""

from typing import Dict, Any, Tuple, Optional, List
import requests
from .base import CloudAPICall


class GetDataset(CloudAPICall):
    """Get a dataset from NDI Cloud."""

    def __init__(self, token: str, cloud_dataset_id: str):
        """
        Initialize GetDataset API call.

        Args:
            token: Authentication token
            cloud_dataset_id: The string ID of the dataset
        """
        super().__init__()
        self.token = token
        self.cloud_dataset_id = cloud_dataset_id
        self.endpoint_name = 'get_dataset'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to get the dataset."""
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.cloud_dataset_id)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.get(api_url, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class ListDatasets(CloudAPICall):
    """List all datasets for an organization."""

    def __init__(self, token: str, organization_id: str):
        """
        Initialize ListDatasets API call.

        Args:
            token: Authentication token
            organization_id: Organization ID
        """
        super().__init__()
        self.token = token
        self.organization_id = organization_id
        self.endpoint_name = 'list_datasets'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to list datasets."""
        api_url = self.get_api_url(self.endpoint_name, organization_id=self.organization_id)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.get(api_url, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class CreateDataset(CloudAPICall):
    """Create a new dataset."""

    def __init__(self, token: str, organization_id: str, dataset_data: Dict[str, Any]):
        """
        Initialize CreateDataset API call.

        Args:
            token: Authentication token
            organization_id: Organization ID
            dataset_data: Dataset metadata (name, description, etc.)
        """
        super().__init__()
        self.token = token
        self.organization_id = organization_id
        self.dataset_data = dataset_data
        self.endpoint_name = 'create_dataset'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to create a dataset."""
        api_url = self.get_api_url(self.endpoint_name, organization_id=self.organization_id)

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.post(api_url, json=self.dataset_data, headers=headers)

        if response.status_code in [200, 201]:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class UpdateDataset(CloudAPICall):
    """Update an existing dataset."""

    def __init__(self, token: str, cloud_dataset_id: str, dataset_data: Dict[str, Any]):
        """
        Initialize UpdateDataset API call.

        Args:
            token: Authentication token
            cloud_dataset_id: Dataset ID
            dataset_data: Updated dataset metadata
        """
        super().__init__()
        self.token = token
        self.cloud_dataset_id = cloud_dataset_id
        self.dataset_data = dataset_data
        self.endpoint_name = 'update_dataset'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to update the dataset."""
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.cloud_dataset_id)

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.put(api_url, json=self.dataset_data, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class DeleteDataset(CloudAPICall):
    """Delete a dataset."""

    def __init__(self, token: str, cloud_dataset_id: str):
        """
        Initialize DeleteDataset API call.

        Args:
            token: Authentication token
            cloud_dataset_id: Dataset ID
        """
        super().__init__()
        self.token = token
        self.cloud_dataset_id = cloud_dataset_id
        self.endpoint_name = 'delete_dataset'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to delete the dataset."""
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.cloud_dataset_id)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.delete(api_url, headers=headers)

        if response.status_code in [200, 204]:
            return True, response.json() if response.text else {}, response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class GetPublished(CloudAPICall):
    """Get published datasets."""

    def __init__(self, token: str, page: int = 1, page_size: int = 20):
        """
        Initialize GetPublished API call.

        Args:
            token: Authentication token
            page: Page number
            page_size: Number of items per page
        """
        super().__init__()
        self.token = token
        self.page = page
        self.page_size = page_size
        self.endpoint_name = 'get_published'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to get published datasets."""
        api_url = self.get_api_url(self.endpoint_name, page=self.page, page_size=self.page_size)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.get(api_url, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class GetUnpublished(CloudAPICall):
    """Get unpublished datasets."""

    def __init__(self, token: str, page: int = 1, page_size: int = 20):
        """
        Initialize GetUnpublished API call.

        Args:
            token: Authentication token
            page: Page number
            page_size: Number of items per page
        """
        super().__init__()
        self.token = token
        self.page = page
        self.page_size = page_size
        self.endpoint_name = 'get_unpublished'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to get unpublished datasets."""
        api_url = self.get_api_url(self.endpoint_name, page=self.page, page_size=self.page_size)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.get(api_url, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class PublishDataset(CloudAPICall):
    """Publish a dataset."""

    def __init__(self, token: str, cloud_dataset_id: str):
        """
        Initialize PublishDataset API call.

        Args:
            token: Authentication token
            cloud_dataset_id: Dataset ID
        """
        super().__init__()
        self.token = token
        self.cloud_dataset_id = cloud_dataset_id
        self.endpoint_name = 'publish_dataset'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to publish the dataset."""
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.cloud_dataset_id)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.post(api_url, headers=headers)

        if response.status_code == 200:
            return True, response.json() if response.text else {}, response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class UnpublishDataset(CloudAPICall):
    """Unpublish a dataset."""

    def __init__(self, token: str, cloud_dataset_id: str):
        """
        Initialize UnpublishDataset API call.

        Args:
            token: Authentication token
            cloud_dataset_id: Dataset ID
        """
        super().__init__()
        self.token = token
        self.cloud_dataset_id = cloud_dataset_id
        self.endpoint_name = 'unpublish_dataset'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to unpublish the dataset."""
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.cloud_dataset_id)

        headers = {
            'Accept': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.post(api_url, headers=headers)

        if response.status_code == 200:
            return True, response.json() if response.text else {}, response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


# Convenience functions
def get_dataset(token: str, cloud_dataset_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get a dataset by ID."""
    api_call = GetDataset(token=token, cloud_dataset_id=cloud_dataset_id)
    return api_call.execute()


def list_datasets(token: str, organization_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """List all datasets for an organization."""
    api_call = ListDatasets(token=token, organization_id=organization_id)
    return api_call.execute()


def create_dataset(token: str, organization_id: str, dataset_data: Dict[str, Any]) -> Tuple[bool, Any, requests.Response, str]:
    """Create a new dataset."""
    api_call = CreateDataset(token=token, organization_id=organization_id, dataset_data=dataset_data)
    return api_call.execute()


def update_dataset(token: str, cloud_dataset_id: str, dataset_data: Dict[str, Any]) -> Tuple[bool, Any, requests.Response, str]:
    """Update an existing dataset."""
    api_call = UpdateDataset(token=token, cloud_dataset_id=cloud_dataset_id, dataset_data=dataset_data)
    return api_call.execute()


def delete_dataset(token: str, cloud_dataset_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Delete a dataset."""
    api_call = DeleteDataset(token=token, cloud_dataset_id=cloud_dataset_id)
    return api_call.execute()


def get_published(token: str, page: int = 1, page_size: int = 20) -> Tuple[bool, Any, requests.Response, str]:
    """Get published datasets."""
    api_call = GetPublished(token=token, page=page, page_size=page_size)
    return api_call.execute()


def get_unpublished(token: str, page: int = 1, page_size: int = 20) -> Tuple[bool, Any, requests.Response, str]:
    """Get unpublished datasets."""
    api_call = GetUnpublished(token=token, page=page, page_size=page_size)
    return api_call.execute()


def publish_dataset(token: str, cloud_dataset_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Publish a dataset."""
    api_call = PublishDataset(token=token, cloud_dataset_id=cloud_dataset_id)
    return api_call.execute()


def unpublish_dataset(token: str, cloud_dataset_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Unpublish a dataset."""
    api_call = UnpublishDataset(token=token, cloud_dataset_id=cloud_dataset_id)
    return api_call.execute()
