"""
Check for required toolboxes and dependencies.

Ported from concept in NDI-MATLAB toolbox checking.
"""

import importlib
from typing import Dict, List, Optional


def check_toolboxes(required: Optional[List[str]] = None) -> Dict[str, bool]:
    """
    Check if required Python packages/toolboxes are installed.

    Args:
        required: List of package names to check (default: common NDI dependencies)

    Returns:
        Dictionary mapping package names to availability (True/False)

    Example:
        >>> status = check_toolboxes(['numpy', 'pandas', 'matplotlib'])
        >>> if not status['numpy']:
        ...     print("NumPy is required but not installed")
    """
    if required is None:
        # Default NDI dependencies
        required = [
            'numpy',
            'pandas',
            'matplotlib',
            'scipy',
            'networkx',
        ]

    status = {}
    for package in required:
        try:
            importlib.import_module(package)
            status[package] = True
        except ImportError:
            status[package] = False

    return status


def assert_toolbox_installed(package: str, message: Optional[str] = None) -> None:
    """
    Assert that a toolbox/package is installed.

    Args:
        package: Package name to check
        message: Optional custom error message

    Raises:
        ImportError: If package is not installed
    """
    try:
        importlib.import_module(package)
    except ImportError as e:
        if message:
            raise ImportError(message) from e
        else:
            raise ImportError(
                f"Required package '{package}' is not installed. "
                f"Install with: pip install {package}"
            ) from e
