"""
Look up entries in NDI Cloud Ontology (deprecated).

This module provides legacy functionality for NDI Cloud ontology lookups.
New code should use ndi.ontology.lookup() instead.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/ndicloud_ontology_lookup.m
"""

import warnings
from typing import Optional, Any, List, Dict
import os


def ndicloud_ontology_lookup(field: str, value: Any) -> Optional[Dict[str, Any]]:
    """
    Look up an entry in NDI Cloud Ontology (deprecated).

    NOTE: This function is deprecated. Use ndi.ontology.lookup() instead.

    Args:
        field: Field to search ('Name', 'Identifier', or 'Description')
        value: Value to search for (exact match)

    Returns:
        Dictionary containing the matching ontology entry, or None if not found

    Raises:
        DeprecationWarning: Always warns that function is deprecated

    Example:
        >>> # Deprecated - do not use in new code
        >>> item = ndicloud_ontology_lookup('Name', 'Left eye view blocked')

    Notes:
        - This function is deprecated and will be removed in a future version
        - Use ndi.ontology.lookup() for new code
        - Searches for exact matches only
        - Loads from NDIC.txt controlled vocabulary file
    """
    warnings.warn(
        "ndicloud_ontology_lookup is deprecated and will be removed soon. "
        "Use ndi.ontology.lookup() instead.",
        DeprecationWarning,
        stacklevel=2
    )

    # Try to load controlled vocabulary file
    try:
        # Get path to controlled vocabulary file
        # This assumes ndi.common.PathConstants exists
        try:
            from ndi.common import PathConstants
            vocab_file = os.path.join(
                PathConstants.CommonFolder,
                'controlled_vocabulary',
                'NDIC.txt'
            )
        except (ImportError, AttributeError):
            # Fallback - construct path
            import ndi
            ndi_path = os.path.dirname(os.path.dirname(ndi.__file__))
            vocab_file = os.path.join(
                ndi_path,
                'common',
                'controlled_vocabulary',
                'NDIC.txt'
            )

        if not os.path.exists(vocab_file):
            warnings.warn(f"Controlled vocabulary file not found: {vocab_file}")
            return None

        # Load the vocabulary file
        entries = load_struct_array(vocab_file)

        # Search for matching entry
        for entry in entries:
            if entry.get(field) == value:
                return entry

        return None

    except Exception as e:
        warnings.warn(f"Error loading ontology: {e}")
        return None


def load_struct_array(filename: str) -> List[Dict[str, Any]]:
    """
    Load a structured array from a text file.

    Args:
        filename: Path to the file to load

    Returns:
        List of dictionaries, each representing an entry

    Notes:
        - File format should be tab or newline delimited
        - First line can be headers
        - This is a simplified implementation
    """
    entries = []

    try:
        with open(filename, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        if not lines:
            return entries

        # Simple parsing - adapt based on actual file format
        # This is a placeholder implementation
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            # Parse line (format-specific)
            # For now, just create a simple entry
            parts = line.split('\t')
            if len(parts) >= 3:
                entry = {
                    'Name': parts[0] if len(parts) > 0 else '',
                    'Identifier': parts[1] if len(parts) > 1 else '',
                    'Description': parts[2] if len(parts) > 2 else '',
                }
                entries.append(entry)

    except Exception as e:
        warnings.warn(f"Error loading file {filename}: {e}")

    return entries
