"""
NDI Ontology PATO - Phenotype And Trait Ontology.

Inherits from Ontology and implements lookup_term_or_id using EBI OLS API.
"""

from typing import Tuple, List
from .ontology import Ontology


class PATO(Ontology):
    """
    PATO - Phenotype And Trait Ontology.

    Uses the EBI OLS API for lookups.
    """

    def __init__(self):
        """Constructor for the PATO ontology object."""
        super().__init__()

    def lookup_term_or_id(self, term_or_id_or_name: str) -> Tuple[str, str, str, List[str]]:
        """
        Look up a term in PATO by ID or name.

        Args:
            term_or_id_or_name: Part after 'PATO:' prefix has been removed

        Returns:
            Tuple of (id, name, definition, synonyms)
        """
        ontology_prefix = 'PATO'
        ontology_name_ols = 'pato'

        try:
            search_query, search_field, lookup_type_msg, _ = Ontology.preprocess_lookup_input(
                term_or_id_or_name, ontology_prefix
            )
        except Exception as e:
            raise ValueError(f'Error preprocessing PATO lookup input "{term_or_id_or_name}": {str(e)}') from e

        try:
            id_val, name, definition, synonyms = Ontology.search_ols_and_perform_iri_lookup(
                search_query, search_field, ontology_name_ols, ontology_prefix, lookup_type_msg
            )
        except Exception as e:
            raise ValueError(f'PATO lookup failed for {lookup_type_msg}: {str(e)}') from e

        return id_val, name, definition, synonyms

    def __repr__(self) -> str:
        """String representation."""
        return "PATO()"
