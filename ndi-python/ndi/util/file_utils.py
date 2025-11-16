"""
File I/O utilities for NDI.

Provides helper functions for file operations.
"""

import os
import shutil
import hashlib
from typing import Optional


def ensure_dir(directory: str) -> None:
    """
    Ensure directory exists, create if necessary.

    Args:
        directory: Path to directory
    """
    os.makedirs(directory, exist_ok=True)


def copy_file_safe(src: str, dst: str, overwrite: bool = False) -> bool:
    """
    Safely copy a file.

    Args:
        src: Source file path
        dst: Destination file path
        overwrite: Whether to overwrite existing file

    Returns:
        True if successful, False otherwise
    """
    if not os.path.exists(src):
        return False

    if os.path.exists(dst) and not overwrite:
        return False

    try:
        shutil.copy2(src, dst)
        return True
    except Exception:
        return False


def file_md5(filename: str) -> Optional[str]:
    """
    Calculate MD5 hash of a file.

    Args:
        filename: Path to file

    Returns:
        MD5 hash string or None if file doesn't exist
    """
    if not os.path.exists(filename):
        return None

    md5_hash = hashlib.md5()
    with open(filename, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            md5_hash.update(chunk)

    return md5_hash.hexdigest()


def get_file_size(filename: str) -> int:
    """
    Get file size in bytes.

    Args:
        filename: Path to file

    Returns:
        File size in bytes, or 0 if file doesn't exist
    """
    if os.path.exists(filename):
        return os.path.getsize(filename)
    return 0
