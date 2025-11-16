"""
NDI Cloud API Users - User management operations.

This module provides user-related API calls for the NDI Cloud.
"""

from typing import Dict, Any, Tuple, Optional
import requests
from .base import CloudAPICall


class GetUser(CloudAPICall):
    """Get user information."""

    def __init__(self, token: str, user_id: str):
        super().__init__()
        self.token = token
        self.user_id = user_id
        self.endpoint_name = 'get_user'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name, user_id=self.user_id)
        headers = {'Accept': 'application/json', 'Authorization': f'Bearer {self.token}'}
        response = requests.get(api_url, headers=headers)
        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


class CreateUser(CloudAPICall):
    """Create a new user."""

    def __init__(self, user_data: Dict[str, Any]):
        super().__init__()
        self.user_data = user_data
        self.endpoint_name = 'create_user'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        api_url = self.get_api_url(self.endpoint_name)
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
        response = requests.post(api_url, json=self.user_data, headers=headers)
        if response.status_code in [200, 201]:
            return True, response.json(), response, api_url
        else:
            return False, response.json() if response.text else response.text, response, api_url


# Convenience functions
def get_user(token: str, user_id: str) -> Tuple[bool, Any, requests.Response, str]:
    """Get user information."""
    return GetUser(token, user_id).execute()


def create_user(user_data: Dict[str, Any]) -> Tuple[bool, Any, requests.Response, str]:
    """Create a new user."""
    return CreateUser(user_data).execute()
