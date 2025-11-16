"""
Run platform compatibility checks.

Platform-specific checks to ensure NDI components work correctly on the
current operating system and Python environment.
"""

from typing import Dict, List, Tuple
import sys
import platform
import warnings


def run_platform_checks(verbose: bool = False) -> Tuple[bool, List[str]]:
    """
    Run platform compatibility checks for NDI.

    Checks that the current platform (OS, Python version, dependencies)
    meets NDI requirements.

    Args:
        verbose: If True, print detailed check results

    Returns:
        Tuple of (all_passed: bool, messages: List[str])
            all_passed: True if all checks passed
            messages: List of informational/warning messages

    Example:
        >>> passed, messages = run_platform_checks(verbose=True)
        >>> if not passed:
        ...     print('Platform checks failed:', messages)

    Note:
        This function performs basic platform checks. More comprehensive
        checking could include:
        - Python version >= 3.8
        - Required packages available (numpy, etc.)
        - File system permissions
        - Platform-specific features (macOS, Linux, Windows)

        Current Status: BASIC IMPLEMENTATION
        Performs minimal platform detection and Python version check.
    """
    messages = []
    all_passed = True

    # Check Python version
    py_version = sys.version_info
    min_version = (3, 8)

    if py_version < min_version:
        messages.append(
            f"WARNING: Python {py_version.major}.{py_version.minor} < "
            f"{min_version[0]}.{min_version[1]} (minimum required)"
        )
        all_passed = False
    else:
        messages.append(
            f"✓ Python {py_version.major}.{py_version.minor} >= "
            f"{min_version[0]}.{min_version[1]}"
        )

    # Check platform
    os_name = platform.system()
    messages.append(f"✓ Operating System: {os_name}")

    # Check architecture
    machine = platform.machine()
    messages.append(f"✓ Architecture: {machine}")

    # Check for optional dependencies
    optional_packages = ['numpy', 'pandas', 'matplotlib']
    for package in optional_packages:
        try:
            __import__(package)
            messages.append(f"✓ Optional package '{package}' available")
        except ImportError:
            messages.append(f"⚠ Optional package '{package}' not found")
            # Not a failure - optional packages

    if verbose:
        for msg in messages:
            print(msg)

    return (all_passed, messages)


def get_platform_info() -> Dict[str, str]:
    """
    Get platform information as a dictionary.

    Returns:
        Dictionary with platform information:
            - python_version: Python version string
            - python_implementation: CPython, PyPy, etc.
            - platform: Operating system name
            - platform_release: OS release/version
            - machine: Architecture (x86_64, arm64, etc.)

    Example:
        >>> info = get_platform_info()
        >>> print(f"Running on {info['platform']} {info['platform_release']}")
    """
    return {
        'python_version': platform.python_version(),
        'python_implementation': platform.python_implementation(),
        'platform': platform.system(),
        'platform_release': platform.release(),
        'machine': platform.machine(),
    }
