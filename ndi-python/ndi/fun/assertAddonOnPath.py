"""
Assert required Python packages are available.

Python equivalent of MATLAB's addon/toolbox checking functionality.
Verifies that required packages are installed and importable.
"""

from typing import List, Optional
import importlib
import warnings


def assertAddonOnPath(
    addon_name: Optional[str] = None,
    required_for: Optional[str] = None
) -> None:
    """
    Assert that required Python package(s) are available.

    Python equivalent: MATLAB's assertAddonOnPath for toolbox checking

    Checks that required Python packages are installed and can be imported.
    Raises an error if any required package is missing.

    Args:
        addon_name: Name of package to check (or None to check all requirements)
        required_for: Description of what the addon is required for

    Raises:
        ImportError: If required package(s) are not available

    Example:
        >>> assertAddonOnPath('numpy', required_for='numerical operations')
        >>> assertAddonOnPath('matplotlib', required_for='plotting')

    Note:
        This is a simplified version. The MATLAB equivalent reads requirements
        from a JSON configuration file. This implementation uses a hardcoded
        list of common NDI requirements.

        For full functionality, would need:
        - JSON configuration file: ndi-python-packages.json
        - Package version checking
        - Optional vs required package distinction
    """
    # Default requirements if no specific addon specified
    if addon_name is None:
        required_addons = _get_requirements()
    else:
        required_addons = [addon_name]

    missing_addons = []

    # Check each required package
    for package in required_addons:
        try:
            importlib.import_module(package)
        except ImportError:
            missing_addons.append(package)

    # Raise error if any are missing
    if missing_addons:
        if len(missing_addons) == 1:
            header = "The following package is required but not found:"
        else:
            header = "The following packages are required but not found:"

        if required_for:
            header = header.replace('required', f'required for "{required_for}"')

        package_list = '\n'.join(f'   {pkg}' for pkg in missing_addons)

        raise ImportError(
            f"{header}\n{package_list}\n\n"
            f"Install with: pip install {' '.join(missing_addons)}"
        )


def check_addon_available(addon_name: str) -> bool:
    """
    Check if a Python package is available (non-raising version).

    Args:
        addon_name: Name of package to check

    Returns:
        bool: True if package is available, False otherwise

    Example:
        >>> if check_addon_available('numpy'):
        ...     import numpy as np
        ...     # Use numpy
    """
    try:
        importlib.import_module(addon_name)
        return True
    except ImportError:
        return False


def _get_requirements() -> List[str]:
    """
    Get list of required Python packages.

    Returns:
        List of required package names

    Note:
        In full implementation, this would read from a JSON configuration file.
        Currently uses a hardcoded list of common NDI requirements.
    """
    # Core requirements
    required = [
        'numpy',
    ]

    # Could extend with optional packages
    # optional = ['pandas', 'matplotlib', 'scipy']

    return required


def get_installed_packages() -> List[str]:
    """
    Get list of installed Python packages.

    Returns:
        List of installed package names

    Note:
        Uses pkg_resources to enumerate installed packages.
        Equivalent to MATLAB's ver() function.
    """
    try:
        import pkg_resources
        installed = [pkg.key for pkg in pkg_resources.working_set]
        return sorted(installed)
    except ImportError:
        warnings.warn(
            "pkg_resources not available, cannot enumerate installed packages",
            UserWarning
        )
        return []
