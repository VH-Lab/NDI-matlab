"""
DID (Digital ID) package integration for NDI.

Provides integration with the DID package for unique identifier generation.
"""

import warnings


def assert_did_installed() -> None:
    """
    Assert that the DID package is installed.

    Raises:
        ImportError: If DID package is not available
    """
    try:
        import did
    except ImportError as e:
        raise ImportError(
            "DID package is required but not installed. "
            "Install with: pip install did"
        ) from e


def check_did_available() -> bool:
    """
    Check if DID package is available.

    Returns:
        bool: True if DID package is installed, False otherwise
    """
    try:
        import did
        return True
    except ImportError:
        return False


def get_did_implementation():
    """
    Get the DID package implementation if available.

    Returns:
        The did module if available, None otherwise
    """
    try:
        import did
        return did
    except ImportError:
        warnings.warn("DID package not available, using fallback identifier generation")
        return None
