"""
Look up entries in the UBERON ontology.

This module provides functionality to search the UBERON (Uber Anatomy Ontology)
for anatomical terms and their identifiers.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/uberon_ontology_lookup.m
"""

from typing import Optional, Dict, Any
import warnings


def uberon_ontology_lookup(field: str, value: Any) -> Optional[Dict[str, Any]]:
    """
    Look up an entry in the UBERON ontology.

    Searches the UBERON (Uber Anatomy Ontology) for anatomical terms.
    This function only finds exact matches.

    Args:
        field: Field to search ('Name', 'Identifier', or 'Description')
        value: Value to search for (string for Name/Description, int/string for Identifier)

    Returns:
        Dictionary with keys 'Name', 'Identifier', 'Description' if found, None otherwise

    Raises:
        ValueError: If field is not one of the supported values

    Example:
        >>> item = uberon_ontology_lookup('Name', 'brain')
        >>> if item:
        ...     print(f"ID: {item['Identifier']}, Name: {item['Name']}")
        >>> item = uberon_ontology_lookup('Identifier', 'UBERON:0000955')
        >>> item = uberon_ontology_lookup('Identifier', 955)  # Also works

    Notes:
        - Requires network access to query UBERON ontology (if using web API)
        - Returns None if no match found
        - This is currently a placeholder/stub implementation
        - Full implementation would query UBERON API or local database
        - See: http://uberon.github.io/
    """
    # Validate field
    valid_fields = ['Name', 'Identifier', 'Description']
    if field not in valid_fields:
        raise ValueError(f"field must be one of {valid_fields}, got '{field}'")

    warnings.warn(
        "uberon_ontology_lookup is a placeholder implementation. "
        "For production use, integrate with UBERON API or local ontology database.",
        UserWarning
    )

    # Placeholder implementation
    # In production, this would:
    # 1. Query UBERON API or local database
    # 2. Parse results
    # 3. Return formatted ontology entry

    # For now, return a hardcoded example for demonstration
    if field == 'Name' and value == 'brain':
        return {
            'Name': 'brain',
            'Identifier': 955,  # UBERON:0000955
            'Description': 'The brain is the center of the nervous system in all vertebrate, and most invertebrate, animals.'
        }
    elif field == 'Identifier':
        # Handle both string and numeric identifiers
        if isinstance(value, str):
            if value.startswith('UBERON:'):
                identifier = int(value.split(':')[1])
            else:
                identifier = int(value)
        else:
            identifier = int(value)

        if identifier == 955:
            return {
                'Name': 'brain',
                'Identifier': 955,
                'Description': 'The brain is the center of the nervous system in all vertebrate, and most invertebrate, animals.'
            }

    # No match found
    return None


def lookup_uberon_term(
    term: str,
    query_fields: str = 'label',
    exact: bool = True
) -> tuple:
    """
    Lower-level UBERON term lookup function.

    This is a helper function used by uberon_ontology_lookup.

    Args:
        term: Term to search for
        query_fields: Fields to query ('label', 'obo_id', etc.)
        exact: If True, require exact match; if False, allow partial matches

    Returns:
        tuple: (labels, docs) where labels is list of matching labels and docs is result structure

    Notes:
        - This is a placeholder implementation
        - Full implementation would use UBERON API or ontology database
    """
    warnings.warn(
        "lookup_uberon_term is a placeholder. Implement with UBERON API integration.",
        UserWarning
    )

    # Placeholder - return empty results
    return [], {}
