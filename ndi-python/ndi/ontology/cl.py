"""
NDI Ontology CL - Cell Ontology.

Inherits from Ontology and implements lookup_term_or_id for CL using EBI OLS API.
"""

from typing import Tuple, List
from .ontology import Ontology


class CL(Ontology):
    """
    CL - NDI Ontology object for the Cell Ontology (CL).

    Uses the EBI OLS API for lookups.

    Examples:
        >>> cl = CL()
        >>> id, name, defn, syn = cl.lookup_term_or_id('0000000')
        >>> id, name, defn, syn = cl.lookup_term_or_id('cell')
    """

    def __init__(self):
        """Constructor for the CL ontology object."""
        super().__init__()

    def lookup_term_or_id(self, term_or_id_or_name: str) -> Tuple[str, str, str, List[str]]:
        """
        Look up a term in the Cell Ontology (CL) by ID or name.

        Args:
            term_or_id_or_name: Part after 'CL:' prefix has been removed
                               (e.g., '0000000' or 'cell')

        Returns:
            Tuple of (id, name, definition, synonyms)

        Notes:
            Uses the EBI OLS API via static helper methods from the base class.
        """
        # Define ontology specifics for CL
        ontology_prefix = 'CL'
        ontology_name_ols = 'cl'

        # Step 1: Preprocess input
        try:
            search_query, search_field, lookup_type_msg, _ = Ontology.preprocess_lookup_input(
                term_or_id_or_name, ontology_prefix
            )
        except Exception as e:
            raise ValueError(f'Error preprocessing CL lookup input "{term_or_id_or_name}": {str(e)}') from e

        # Step 2: Perform search and IRI lookup
        try:
            id_val, name, definition, synonyms = Ontology.search_ols_and_perform_iri_lookup(
                search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg
            )
        except Exception as e:
            raise ValueError(f'CL lookup failed for {lookup_type_msg}: {str(e)}') from e

        return id_val, name, definition, synonyms

    def __repr__(self) -> str:
        """String representation."""
        return "CL()"
