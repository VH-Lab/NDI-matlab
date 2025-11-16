"""
NDI Cloud API Documents - Document management operations.

This module provides document-related API calls for the NDI Cloud.
"""

from typing import Dict, Any, Tuple, Optional, List
import requests
from .base import CloudAPICall


class GetDocument(CloudAPICall):
    """Get a document from a dataset."""

    def __init__(self, token: str, dataset_id: str, document_id: str):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.document_id = document_id
        self.endpoint_name = 'get_document'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id, document_id=self.document_id)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class ListDatasetDocuments(CloudAPICall):
    """List documents in a dataset (paginated)."""

    def __init__(self, token: str, dataset_id: str, page: int = 1, page_size: int = 20):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.page = page
        self.page_size = page_size
        self.endpoint_name = 'list_dataset_documents'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id, page=self.page, page_size=self.page_size)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class AddDocument(CloudAPICall):
    """Add a document to a dataset."""

    def __init__(self, token: str, dataset_id: str, document_data: Dict[str, Any]):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.document_data = document_data
        self.endpoint_name = 'add_document'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id)
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.post(api_url, json=self.document_data, headers=headers)
        if response.status_code in [200, 201]:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class UpdateDocument(CloudAPICall):
    """Update a document in a dataset."""

    def __init__(self, token: str, dataset_id: str, document_id: str, document_data: Dict[str, Any]):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.document_id = document_id
        self.document_data = document_data
        self.endpoint_name = 'update_document'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id, document_id=self.document_id)
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.put(api_url, json=self.document_data, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class DeleteDocument(CloudAPICall):
    """Delete a document from a dataset."""

    def __init__(self, token: str, dataset_id: str, document_id: str):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.document_id = document_id
        self.endpoint_name = 'delete_document'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id, document_id=self.document_id)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.delete(api_url, headers=headers)
        if response.status_code in [200, 204]:
            return True, response.json() if response.text else {}, response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class DocumentCount(CloudAPICall):
    """Get document count for a dataset."""

    def __init__(self, token: str, dataset_id: str):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.endpoint_name = 'document_count'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


# Convenience functions
def get_document(token: str, dataset_id: str, document_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get a document by ID."""
    return GetDocument(token, dataset_id, document_id).execute()


def list_dataset_documents(token: str, dataset_id: str, page: int = 1, page_size: int = 20) -> Tuple[bool, Any, requests.Response, str]:
    """List documents in a dataset."""
    return ListDatasetDocuments(token, dataset_id, page, page_size).execute()


def add_document(token: str, dataset_id: str, document_data: Dict[str, Any]) -> Tuple[bool, Any, requests.Response, str]:
    """Add a document to a dataset."""
    return AddDocument(token, dataset_id, document_data).execute()


def update_document(token: str, dataset_id: str, document_id: str, document_data: Dict[str, Any]) -> Tuple[bool, Any, requests.Response, str]:
    """Update a document."""
    return UpdateDocument(token, dataset_id, document_id, document_data).execute()


def delete_document(token: str, dataset_id: str, document_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Delete a document."""
    return DeleteDocument(token, dataset_id, document_id).execute()


def document_count(token: str, dataset_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get document count for a dataset."""
    return DocumentCount(token, dataset_id).execute()
