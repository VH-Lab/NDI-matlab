"""
Path constants for NDI.

This module provides centralized path configuration for NDI,
including paths to common folders, vocabularies, and resources.

Ported from MATLAB: ndi.common.PathConstants
"""

import os
from pathlib import Path
from typing import Optional


class PathConstants:
    """
    Centralized path configuration for NDI.

    Provides paths to NDI installation directory, common resources,
    controlled vocabularies, and user data directories.
    """

    _ndi_root: Optional[str] = None
    _common_folder: Optional[str] = None
    _user_folder: Optional[str] = None

    @classmethod
    def get_ndi_root(cls) -> str:
        """
        Get the NDI installation root directory.

        Returns:
            str: Path to NDI root directory
        """
        if cls._ndi_root is None:
            # Find ndi package root
            import ndi
            cls._ndi_root = os.path.dirname(os.path.dirname(ndi.__file__))
        return cls._ndi_root

    @classmethod
    def get_common_folder(cls) -> str:
        """
        Get the common resources folder.

        Returns:
            str: Path to common folder with shared resources
        """
        if cls._common_folder is None:
            cls._common_folder = os.path.join(cls.get_ndi_root(), 'common')
            os.makedirs(cls._common_folder, exist_ok=True)
        return cls._common_folder

    @classmethod
    def get_user_folder(cls) -> str:
        """
        Get the user data folder.

        Returns:
            str: Path to user-specific NDI data folder
        """
        if cls._user_folder is None:
            cls._user_folder = os.path.join(str(Path.home()), '.ndi')
            os.makedirs(cls._user_folder, exist_ok=True)
        return cls._user_folder

    @classmethod
    def get_controlled_vocabulary_folder(cls) -> str:
        """
        Get the controlled vocabulary folder.

        Returns:
            str: Path to controlled vocabulary files
        """
        vocab_folder = os.path.join(cls.get_common_folder(), 'controlled_vocabulary')
        os.makedirs(vocab_folder, exist_ok=True)
        return vocab_folder

    # Class properties for backward compatibility
    @classmethod
    @property
    def NDIRoot(cls) -> str:
        """NDI root directory (MATLAB-style name)."""
        return cls.get_ndi_root()

    @classmethod
    @property
    def CommonFolder(cls) -> str:
        """Common folder directory (MATLAB-style name)."""
        return cls.get_common_folder()

    @classmethod
    @property
    def UserFolder(cls) -> str:
        """User folder directory (MATLAB-style name)."""
        return cls.get_user_folder()
