"""
NDI Cloud API Files - File management operations.

This module provides file-related API calls for the NDI Cloud.
"""

from typing import Dict, Any, Tuple, Optional, List
import requests
from .base import CloudAPICall


class GetFile(CloudAPICall):
    """Get a file from a dataset."""

    def __init__(self, token: str, dataset_id: str, file_uid: str):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.file_uid = file_uid
        self.endpoint_name = 'get_file'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id, file_uid=self.file_uid)
        headers = {'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.content, response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class GetFileDetails(CloudAPICall):
    """Get file details/metadata."""

    def __init__(self, token: str, dataset_id: str, file_uid: str):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.file_uid = file_uid
        self.endpoint_name = 'get_file_details'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id, file_uid=self.file_uid)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class GetFileUploadURL(CloudAPICall):
    """Get a pre-signed URL for file upload."""

    def __init__(self, token: str, organization_id: str, dataset_id: str, file_uid: str):
        super().__init__()
        self.token = token
        self.organization_id = organization_id
        self.dataset_id = dataset_id
        self.file_uid = file_uid
        self.endpoint_name = 'get_file_upload_url'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, organization_id=self.organization_id,
                                   dataset_id=self.dataset_id, file_uid=self.file_uid)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class ListFiles(CloudAPICall):
    """List files in a dataset."""

    def __init__(self, token: str, dataset_id: str):
        super().__init__()
        self.token = token
        self.dataset_id = dataset_id
        self.endpoint_name = 'list_files'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, dataset_id=self.dataset_id)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


# Convenience functions
def get_file(token: str, dataset_id: str, file_uid: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get a file by UID."""
    return GetFile(token, dataset_id, file_uid).execute()


def get_file_details(token: str, dataset_id: str, file_uid: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get file details."""
    return GetFileDetails(token, dataset_id, file_uid).execute()


def get_file_upload_url(token: str, organization_id: str, dataset_id: str, file_uid: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get pre-signed upload URL."""
    return GetFileUploadURL(token, organization_id, dataset_id, file_uid).execute()


def list_files(token: str, dataset_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """List files in a dataset."""
    return ListFiles(token, dataset_id).execute()
