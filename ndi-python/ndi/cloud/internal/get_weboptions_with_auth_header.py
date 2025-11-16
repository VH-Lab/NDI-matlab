"""
Create HTTP headers with Authorization for NDI cloud API requests.

This module provides a helper function to generate properly authenticated
HTTP headers for cloud API calls.

MATLAB Source: ndi/+ndi/+cloud/+internal/getWeboptionsWithAuthHeader.m
"""

from typing import Dict, Optional


def get_weboptions_with_auth_header(token: Optional[str] = None) -> Dict[str, str]:
    """
    Create HTTP headers with Authorization for API requests.

    This function creates a dictionary of HTTP headers that is pre-configured
    with the 'Authorization' header required for NDI cloud API requests.

    If no token is provided, it attempts to obtain an authentication token
    from environment variables. It then constructs the header value in the
    format "Bearer <token>" and returns it in a dictionary suitable for use
    with the requests library.

    This is a convenience function to ensure that API calls are properly
    authenticated without duplicating header creation code.

    Args:
        token: Optional authentication token. If not provided, will attempt
            to retrieve from environment variables via get_active_token()

    Returns:
        A dictionary containing HTTP headers with the 'Authorization' field set.
        Also includes 'Accept' and 'Content-Type' headers for JSON.

    Raises:
        RuntimeError: If no valid authentication token is available

    Example:
        >>> from ndi.cloud.internal import get_weboptions_with_auth_header
        >>> import requests
        >>>
        >>> # Create headers for an authenticated API call
        >>> headers = get_weboptions_with_auth_header()
        >>>
        >>> # Use headers in a request
        >>> response = requests.get('https://api.ndi.cloud/endpoint', headers=headers)
        >>>
        >>> # Or provide your own token
        >>> headers = get_weboptions_with_auth_header(token='my_jwt_token')

    Note:
        In MATLAB, this returns a weboptions object. In Python, we return a
        dictionary of headers suitable for use with the requests library.

    See Also:
        get_active_token

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/getWeboptionsWithAuthHeader.m
    """
    # If no token provided, get it from environment
    if token is None:
        # Import here to avoid circular imports
        from .get_active_token import get_active_token

        auth_token, _ = get_active_token()

        if not auth_token:
            raise RuntimeError(
                "No valid authentication token available. "
                "Please set NDI_CLOUD_TOKEN environment variable or provide a token."
            )
    else:
        auth_token = token

    # Create headers dictionary with Authorization
    headers = {
        'Authorization': f'Bearer {auth_token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    }

    return headers
