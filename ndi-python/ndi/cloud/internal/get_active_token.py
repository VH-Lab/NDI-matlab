"""
Retrieve the active NDI cloud authentication token and organization ID.

This module retrieves and validates the cloud authentication credentials
from environment variables.

MATLAB Source: ndi/+ndi/+cloud/+internal/getActiveToken.m
"""

import os
from typing import Tuple, Optional
from datetime import datetime


def get_active_token() -> Tuple[str, str]:
    """
    Retrieve the active NDI cloud token and organization ID.

    This function retrieves the NDI cloud authentication token and the
    organization ID from the environment variables 'NDI_CLOUD_TOKEN' and
    'NDI_CLOUD_ORGANIZATION_ID', respectively.

    After retrieving the token, it checks if the token has expired using the
    get_token_expiration function. If the token is expired, an empty string
    is returned for the token.

    Returns:
        Tuple containing:
            - token (str): The active NDI cloud authentication token. Returns an
              empty string if the token is not found or has expired.
            - organization_id (str): The NDI cloud organization ID.

    Example:
        >>> from ndi.cloud.internal import get_active_token
        >>> my_token, my_org = get_active_token()
        >>> if not my_token:
        ...     raise RuntimeError('No active token found.')
        >>> print(f'Using organization: {my_org}')

    Note:
        This function expects the following environment variables to be set:
        - NDI_CLOUD_TOKEN: The JWT authentication token
        - NDI_CLOUD_ORGANIZATION_ID: The organization identifier

    See Also:
        get_token_expiration

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/getActiveToken.m
    """
    from .get_token_expiration import get_token_expiration

    # Get token and organization ID from environment variables
    token = os.environ.get('NDI_CLOUD_TOKEN', '')
    organization_id = os.environ.get('NDI_CLOUD_ORGANIZATION_ID', '')

    # Check if token has expired
    if token:
        try:
            expiration_time = get_token_expiration(token)
            current_time = datetime.now(expiration_time.tzinfo)

            if current_time > expiration_time:
                # Token has expired, return empty string
                token = ''
        except Exception:
            # If there's any error checking expiration, treat as expired
            token = ''

    return token, organization_id
