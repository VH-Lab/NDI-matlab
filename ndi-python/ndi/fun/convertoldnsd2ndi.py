"""
Convert old NSD session to NDI format.

MATLAB source: ndi/+ndi/+fun/convertoldnsd2ndi.m

This module provides legacy migration from the old 'nsd' naming convention
to the modern 'ndi' convention. This is deprecated functionality.
"""

from pathlib import Path
from typing import Union
import warnings


def convertoldnsd2ndi(pathname: Union[str, Path]) -> None:
    """
    Convert an old 'nsd' session to 'ndi' format.

    MATLAB equivalent: ndi.fun.convertoldnsd2ndi()

    DEPRECATED: This function is deprecated as all modern NDI installations
    use the 'ndi' naming convention. Kept for historical compatibility only.

    Converts the NSD_SESSION_DIR session at pathname to the new 'ndi' name
    convention by making the following irreversible changes:

    1. Any instance of 'nsd' in a filename is changed to 'ndi'
    2. Any instance of 'NSD' in a filename is changed to 'NDI'
    3. All instances of 'nsd' in .m, .json, .txt files are replaced with 'ndi'
    4. All instances of 'NSD' in .m, .json, .txt files are replaced with 'NDI'

    Args:
        pathname: Path to NSD session directory to convert

    Raises:
        NotImplementedError: This is deprecated functionality
        DeprecationWarning: Always raised to warn about deprecated function

    Example:
        >>> convertoldnsd2ndi('/path/to/old_nsd_session')  # Don't use!

    Note:
        DEPRECATED: Do not use this function. All NDI installations should
        already be using the 'ndi' naming convention.

        This function would require:
        - File system traversal and renaming
        - Text file content replacement
        - Backup and recovery mechanisms

        Current Status: NOT IMPLEMENTED (deprecated functionality)
    """
    warnings.warn(
        "convertoldnsd2ndi is DEPRECATED. "
        "All NDI installations should use 'ndi' naming convention. "
        "This legacy migration tool is not implemented in Python NDI.",
        DeprecationWarning,
        stacklevel=2
    )

    raise NotImplementedError(
        "convertoldnsd2ndi is deprecated functionality not implemented in Python NDI. "
        "All modern NDI installations use 'ndi' naming convention. "
        "If you have a legacy 'nsd' session, please use the MATLAB version "
        "to convert it, or manually rename files from 'nsd' to 'ndi'."
    )
