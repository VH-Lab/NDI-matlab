"""
NDI Cloud API Authentication - User authentication operations.

This module provides authentication-related API calls for the NDI Cloud.
"""

from typing import Dict, Any, Tuple, Optional
import requests
from .base import CloudAPICall


class Login(CloudAPICall):
    """
    Implementation class for user authentication.

    Authenticates a user with the NDI Cloud and returns an authentication
    token and user information.

    Example:
        >>> login = Login(email='user@example.com', password='password')
        >>> success, answer, response, url = login.execute()
        >>> if success:
        ...     token = answer['token']
        ...     org_id = answer['user']['organizations'][0]['id']
    """

    def __init__(self, email: str, password: str):
        """
        Initialize Login API call.

        Args:
            email: The user's email address
            password: The user's password
        """
        super().__init__()
        self.email = email
        self.password = password
        self.endpoint_name = 'login'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """
        Perform the API call to log in the user.

        Returns:
            Tuple of (success, answer, response, api_url)
        """
        api_url = self.get_api_url(self.endpoint_name)

        json_data = {
            'email': self.email,
            'password': self.password
        }

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }

        response = requests.post(api_url, json=json_data, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class Logout(CloudAPICall):
    """Logout API call."""

    def __init__(self, token: str):
        """
        Initialize Logout API call.

        Args:
            token: Authentication token
        """
        super().__init__()
        self.token = token
        self.endpoint_name = 'logout'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to log out the user."""
        api_url = self.get_api_url(self.endpoint_name)

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


class VerifyUser(CloudAPICall):
    """Verify user API call."""

    def __init__(self, verification_code: str):
        """
        Initialize VerifyUser API call.

        Args:
            verification_code: User verification code
        """
        super().__init__()
        self.verification_code = verification_code
        self.endpoint_name = 'verify_user'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to verify the user."""
        api_url = self.get_api_url(self.endpoint_name)

        json_data = {'code': self.verification_code}

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }

        response = requests.post(api_url, json=json_data, headers=headers)

        if response.status_code == 200:
            return True, response.json(), response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class ChangePassword(CloudAPICall):
    """Change password API call."""

    def __init__(self, token: str, old_password: str, new_password: str):
        """
        Initialize ChangePassword API call.

        Args:
            token: Authentication token
            old_password: Current password
            new_password: New password
        """
        super().__init__()
        self.token = token
        self.old_password = old_password
        self.new_password = new_password
        self.endpoint_name = 'change_password'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to change password."""
        api_url = self.get_api_url(self.endpoint_name)

        json_data = {
            'oldPassword': self.old_password,
            'newPassword': self.new_password
        }

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {self.token}'
        }

        response = requests.put(api_url, json=json_data, headers=headers)

        if response.status_code == 200:
            return True, response.json() if response.text else {}, response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class ResetPassword(CloudAPICall):
    """Reset password (forgot password) API call."""

    def __init__(self, email: str):
        """
        Initialize ResetPassword API call.

        Args:
            email: User's email address
        """
        super().__init__()
        self.email = email
        self.endpoint_name = 'reset_password'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to request password reset."""
        api_url = self.get_api_url(self.endpoint_name)

        json_data = {'email': self.email}

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }

        response = requests.post(api_url, json=json_data, headers=headers)

        if response.status_code == 200:
            return True, response.json() if response.text else {}, response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


class ResendConfirmation(CloudAPICall):
    """Resend confirmation email API call."""

    def __init__(self, email: str):
        """
        Initialize ResendConfirmation API call.

        Args:
            email: User's email address
        """
        super().__init__()
        self.email = email
        self.endpoint_name = 'resend_confirmation'

    def execute(self) -> Tuple[bool, Any, requests.Response, str]:
        """Perform the API call to resend confirmation email."""
        api_url = self.get_api_url(self.endpoint_name)

        json_data = {'email': self.email}

        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }

        response = requests.post(api_url, json=json_data, headers=headers)

        if response.status_code == 200:
            return True, response.json() if response.text else {}, response, api_url
        else:
            try:
                answer = response.json()
            except Exception:
                answer = response.text
            return False, answer, response, api_url


# Convenience functions
def login(email: str, password: str) -> Tuple[bool, Any, requests.Response, str]:
    """
    Authenticate a user and retrieve a token.

    Args:
        email: The user's email address
        password: The user's password

    Returns:
        Tuple of (success, answer, response, api_url) where answer contains
        'token' and 'user' info on success

    Example:
        >>> success, auth_info, response, url = login('user@example.com', 'mypassword')
        >>> if success:
        ...     token = auth_info['token']
        ...     org_id = auth_info['user']['organizations'][0]['id']
    """
    api_call = Login(email=email, password=password)
    return api_call.execute()


def logout(token: str) -> Tuple[bool, Any, requests.Response, str]:
    """Logout a user."""
    api_call = Logout(token=token)
    return api_call.execute()


def verify_user(verification_code: str) -> Tuple[bool, Any, requests.Response, str]:
    """Verify a user with verification code."""
    api_call = VerifyUser(verification_code=verification_code)
    return api_call.execute()


def change_password(token: str, old_password: str, new_password: str) -> Tuple[bool, Any, requests.Response, str]:
    """Change user password."""
    api_call = ChangePassword(token=token, old_password=old_password, new_password=new_password)
    return api_call.execute()


def reset_password(email: str) -> Tuple[bool, Any, requests.Response, str]:
    """Request password reset."""
    api_call = ResetPassword(email=email)
    return api_call.execute()


def resend_confirmation(email: str) -> Tuple[bool, Any, requests.Response, str]:
    """Resend confirmation email."""
    api_call = ResendConfirmation(email=email)
    return api_call.execute()
