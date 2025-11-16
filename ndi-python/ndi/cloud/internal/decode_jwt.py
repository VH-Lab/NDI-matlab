"""
Decode a JSON Web Token (JWT) and extract its payload.

This module provides JWT decoding functionality for NDI cloud authentication.
Supports both PyJWT library (preferred) and base64 fallback for basic decoding.

MATLAB Source: ndi/+ndi/+cloud/+internal/decodeJwt.m
"""

import base64
import json
from typing import Dict, Any


def decode_jwt(jwt_token: str) -> Dict[str, Any]:
    """
    Decode a JSON Web Token (JWT) and return its payload.

    This function takes a standard JSON Web Token (JWT) as input and extracts
    the payload section. The payload is Base64Url-decoded and then parsed as a
    JSON string to produce a Python dictionary.

    This function handles the character replacements ('-' to '+', '_' to '/')
    and padding required to convert from Base64Url encoding to standard Base64
    encoding before decoding.

    The function first attempts to use the PyJWT library if available for proper
    JWT validation. If PyJWT is not available, it falls back to basic base64
    decoding without signature verification.

    Args:
        jwt_token: The JSON Web Token string to be decoded

    Returns:
        A dictionary representing the JSON payload of the token

    Raises:
        ValueError: If the token format is invalid or cannot be decoded
        json.JSONDecodeError: If the payload is not valid JSON

    Example:
        >>> from ndi.cloud.internal import decode_jwt
        >>> # Assume jwt is a valid JWT string
        >>> payload = decode_jwt(jwt)
        >>> print(payload)
        >>> # Access specific claims
        >>> user_id = payload.get('sub')
        >>> expiration = payload.get('exp')

    Note:
        This function does NOT verify the token signature. For production use
        with signature verification, consider using PyJWT library directly.

    See Also:
        get_token_expiration

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/decodeJwt.m
    """
    if not isinstance(jwt_token, str):
        raise ValueError("JWT token must be a string")

    # Try using PyJWT if available (preferred method)
    try:
        import jwt
        # Decode without verification (matching MATLAB behavior)
        decoded_payload = jwt.decode(jwt_token, options={"verify_signature": False})
        return decoded_payload
    except ImportError:
        # Fall back to manual base64 decoding if PyJWT is not available
        pass

    # Manual decoding (fallback method)
    # Split the token into its components
    token_parts = jwt_token.split('.')

    if len(token_parts) != 3:
        raise ValueError(
            f"Invalid JWT format: expected 3 parts separated by '.', "
            f"got {len(token_parts)} parts"
        )

    # Extract and decode the payload (second part)
    payload_base64 = token_parts[1]

    # Convert Base64Url to standard Base64
    # Replace URL-safe characters
    payload_base64 = payload_base64.replace('-', '+').replace('_', '/')

    # Add padding if necessary
    # Base64 strings should be multiples of 4 characters
    padding_needed = len(payload_base64) % 4
    if padding_needed > 0:
        payload_base64 += '=' * (4 - padding_needed)

    try:
        # Decode from Base64
        payload_bytes = base64.b64decode(payload_base64)

        # Convert bytes to string (UTF-8)
        payload_json = payload_bytes.decode('utf-8')

        # Parse JSON to dictionary
        decoded_payload = json.loads(payload_json)

        return decoded_payload

    except (base64.binascii.Error, UnicodeDecodeError) as e:
        raise ValueError(f"Failed to decode JWT payload: {str(e)}") from e
    except json.JSONDecodeError as e:
        raise ValueError(f"JWT payload is not valid JSON: {str(e)}") from e
