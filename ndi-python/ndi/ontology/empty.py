"""
NDI Ontology EMPTY - Empty placeholder ontology.
"""

from typing import Tuple, List
from .ontology import Ontology


class EMPTY(Ontology):
    """
    EMPTY - Empty placeholder ontology.

    Returns empty values for all lookups.
    """

    def __init__(self):
        """Constructor for EMPTY ontology."""
        super().__init__()

    def lookup_term_or_id(self, term_or_id_or_name: str) -> Tuple[str, str, str, List[str]]:
        """
        Look up a term (always returns empty).

        Args:
            term_or_id_or_name: Input term/ID/name (ignored)

        Returns:
            Tuple of ('', '', '', [])
        """
        return '', '', '', []

    def __repr__(self) -> str:
        """String representation."""
        return "EMPTY()"
