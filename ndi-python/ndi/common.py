"""
Common path constants and utilities for NDI.

This module provides path constants referenced throughout the NDI toolbox,
matching the functionality of ndi.common.PathConstants in the MATLAB version.
"""

import os
import tempfile
from pathlib import Path
from typing import List


def toolboxdir() -> str:
    """
    Returns the root directory of the NDI toolbox.

    Returns the absolute path to the root directory of the NDI toolbox.
    This function is useful for locating resources within the toolbox
    structure regardless of the current working directory.

    Returns:
        str: The absolute path to the root directory of the NDI toolbox

    Example:
        >>> root_dir = toolboxdir()
        >>> print(f'NDI toolbox is installed at: {root_dir}')
    """
    # Get the directory containing this file (ndi/common.py)
    # Go up one level to get the ndi-python root
    current_file = Path(__file__).resolve()
    ndi_package_dir = current_file.parent  # ndi/
    toolbox_root = ndi_package_dir.parent  # ndi-python/
    return str(toolbox_root)


class PathConstants:
    """
    A set of path constants referenced by the NDI toolbox.

    Attributes:
        root_folder: The path of the NDI distribution on this machine
        common_folder: The path to the package ndi_common
        document_folder: The path of the NDI document definitions
        document_schema_folder: The path of the NDI document validation schema
        example_data_folder: The path to the NDI example sessions
        preferences: A path to a directory of preferences files
        file_cache_folder: A path where files may be cached
        temp_folder: The path to a directory for temporary files
        test_folder: A path to a safe place to run test code
        log_folder: A path to a directory for storing logs
    """

    def __init__(self):
        """PathConstants should not be instantiated. Use class methods."""
        raise RuntimeError("PathConstants is a static class and should not be instantiated")

    @classmethod
    def root_folder(cls) -> str:
        """The path of the NDI distribution on this machine."""
        return toolboxdir()

    @classmethod
    def common_folder(cls) -> str:
        """The path to the package ndi_common."""
        # Look for ndi_common in the parent directory (NDI-matlab/)
        toolbox_root = Path(cls.root_folder())

        # First check if we're in ndi-python, then look for ndi_common in parent
        if toolbox_root.name == 'ndi-python':
            matlab_root = toolbox_root.parent
            common_path = matlab_root / 'src' / 'ndi' / 'ndi_common'
        else:
            # Otherwise assume we're already in the right place
            common_path = toolbox_root / 'ndi_common'

        if not common_path.exists():
            # Fallback: look in several possible locations
            possible_paths = [
                Path(cls.root_folder()) / '..' / 'src' / 'ndi' / 'ndi_common',
                Path(cls.root_folder()) / '..' / 'ndi_common',
                Path(cls.root_folder()) / 'ndi_common',
            ]
            for path in possible_paths:
                resolved = path.resolve()
                if resolved.exists():
                    return str(resolved)

            # If still not found, return the expected path
            # (it will fail later if truly needed)
            return str(common_path)

        return str(common_path)

    @classmethod
    def document_folder(cls) -> str:
        """The path of the NDI document definitions."""
        return os.path.join(cls.common_folder(), 'database_documents')

    @classmethod
    def document_schema_folder(cls) -> str:
        """The path of the NDI document validation schema."""
        return os.path.join(cls.common_folder(), 'schema_documents')

    @classmethod
    def example_data_folder(cls) -> str:
        """The path to the NDI example sessions."""
        return os.path.join(cls.common_folder(), 'example_sessions')

    @classmethod
    def temp_folder(cls) -> str:
        """The path to a directory that may be used for temporary files."""
        temp_dir = os.path.join(tempfile.gettempdir(), 'nditemp')
        cls._ensure_writable(temp_dir)
        return temp_dir

    @classmethod
    def test_folder(cls) -> str:
        """A path to a safe place to run test code."""
        test_dir = os.path.join(tempfile.gettempdir(), 'nditestcode')
        cls._ensure_writable(test_dir)
        return test_dir

    @classmethod
    def file_cache_folder(cls) -> str:
        """A path where files may be cached (not deleted every time)."""
        # Use user's home directory for cache
        home = Path.home()
        cache_dir = home / 'Documents' / 'NDI' / 'NDI-filecache'
        cache_path = str(cache_dir)
        cls._ensure_writable(cache_path)
        return cache_path

    @classmethod
    def log_folder(cls) -> str:
        """A path to a directory for storing logs."""
        home = Path.home()
        log_dir = home / 'Documents' / 'NDI' / 'Logs'
        log_path = str(log_dir)
        cls._ensure_writable(log_path)
        return log_path

    @classmethod
    def preferences(cls) -> str:
        """A path to a directory of preferences files."""
        home = Path.home()

        # Platform-specific preferences location
        if os.name == 'nt':  # Windows
            pref_dir = home / 'AppData' / 'Roaming' / 'NDI' / 'Preferences'
        elif os.name == 'posix':  # Linux/Mac
            if os.uname().sysname == 'Darwin':  # macOS
                pref_dir = home / 'Library' / 'Preferences' / 'NDI'
            else:  # Linux
                pref_dir = home / '.config' / 'NDI' / 'Preferences'
        else:
            pref_dir = home / '.ndi' / 'Preferences'

        pref_path = str(pref_dir)
        cls._ensure_writable(pref_path)
        return pref_path

    @classmethod
    def calc_doc(cls) -> List[str]:
        """A list of paths to NDI calculator document definitions."""
        # For now, return the main database_documents folder
        # In full implementation, this would search for all calculator docs
        return [cls.document_folder()]

    @classmethod
    def calc_doc_schema(cls) -> List[str]:
        """A list of paths to NDI calculator document schemas."""
        # For now, return the main schema_documents folder
        # In full implementation, this would search for all calculator schemas
        return [cls.document_schema_folder()]

    @staticmethod
    def _ensure_writable(folder_path: str) -> None:
        """
        Ensure a folder exists and is writable.

        Args:
            folder_path: Path to the folder to check/create

        Raises:
            PermissionError: If the folder is not writable
        """
        # Create directory if it doesn't exist
        os.makedirs(folder_path, exist_ok=True)

        # Test write access
        test_file = os.path.join(folder_path, '.ndi_write_test')
        try:
            with open(test_file, 'w') as f:
                f.write('test')
            os.remove(test_file)
        except (IOError, OSError) as e:
            folder_name = os.path.basename(folder_path)
            raise PermissionError(
                f'We do not have write access to the "{folder_name}" at {folder_path}'
            ) from e


# Convenience module-level functions
def root_folder() -> str:
    """Get the NDI root folder."""
    return PathConstants.root_folder()


def common_folder() -> str:
    """Get the ndi_common folder."""
    return PathConstants.common_folder()


def document_folder() -> str:
    """Get the database_documents folder."""
    return PathConstants.document_folder()


def document_schema_folder() -> str:
    """Get the schema_documents folder."""
    return PathConstants.document_schema_folder()
