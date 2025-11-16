"""
Find NDI calculator toolbox directories.

This module scans for installed NDI calculator toolboxes.

Ported from MATLAB: src/ndi/+ndi/+fun/find_calc_directories.m
"""

import os
import glob
from typing import List


def find_calc_directories() -> List[str]:
    """
    Find all NDI calculator toolbox directories.

    Scans for installed NDI calculator toolboxes that follow the naming
    convention 'NDIcalc-*-python' or 'NDIcalc*-python'.

    Returns:
        List of paths to calculator directories

    Example:
        >>> calc_dirs = find_calc_directories()
        >>> print(f"Found {len(calc_dirs)} calculator directories")
    """
    calc_dirs = []

    try:
        # Get NDI installation directory
        import ndi
        ndi_dir = os.path.dirname(os.path.dirname(ndi.__file__))

        # Navigate up to find sibling calculator directories
        base_path = os.path.dirname(os.path.dirname(os.path.dirname(ndi_dir)))

        if not os.path.isdir(base_path):
            return calc_dirs

        # Search for calculator directories
        pattern = os.path.join(base_path, 'NDIcalc*-python')
        matches = glob.glob(pattern)

        # Filter for actual directories
        calc_dirs = [m for m in matches if os.path.isdir(m)]

    except Exception:
        pass  # Return empty list on error

    return calc_dirs
