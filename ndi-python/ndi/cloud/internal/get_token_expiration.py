"""
Extract the expiration time from a JWT authentication token.

This module decodes a JWT token to retrieve its expiration timestamp
and converts it to a Python datetime object.

MATLAB Source: ndi/+ndi/+cloud/+internal/getTokenExpiration.m
"""

from datetime import datetime, timezone


def get_token_expiration(token: str) -> datetime:
    """
    Return the expiration time of a JWT.

    This function decodes a JSON Web Token (JWT) to extract its expiration
    time. The expiration time, which is typically provided in POSIX/Unix time
    (seconds since 1970-01-01 UTC), is converted to a Python datetime object
    in the local time zone.

    Args:
        token: The JSON Web Token from which to extract the expiration time

    Returns:
        A datetime object representing the token's expiration time,
        with timezone information (local timezone)

    Raises:
        ValueError: If the token cannot be decoded or does not contain
            an expiration claim
        KeyError: If the 'exp' field is not present in the token payload

    Example:
        >>> from ndi.cloud.internal import get_token_expiration
        >>> from datetime import datetime
        >>> # Assume jwt is a valid JWT string
        >>> exp_time = get_token_expiration(jwt)
        >>> if datetime.now(exp_time.tzinfo) > exp_time:
        ...     print('Token has expired.')
        ... else:
        ...     print(f'Token expires at: {exp_time}')

    See Also:
        decode_jwt

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+internal/getTokenExpiration.m
    """
    from .decode_jwt import decode_jwt

    # Decode the token to get the payload
    decoded_token = decode_jwt(token)

    # Extract the expiration time (in POSIX time)
    if 'exp' not in decoded_token:
        raise KeyError("Token does not contain an 'exp' (expiration) claim")

    exp_timestamp = decoded_token['exp']

    # Convert from POSIX time to datetime
    # Create datetime in UTC first
    expiration_time = datetime.fromtimestamp(exp_timestamp, tz=timezone.utc)

    # Convert to local timezone
    expiration_time = expiration_time.astimezone()

    return expiration_time
