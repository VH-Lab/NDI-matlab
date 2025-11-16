"""
NDI Ontology EMPTY - Experimental Measurements, Purposes, and Treatments ontologY.

This module provides access to the EMPTY ontology, which is stored in OBO format.
EMPTY contains terms for experimental measurements, purposes, and treatments used
in neuroscience research.

MATLAB Source: ndi/+ndi/+ontology/EMPTY.m
"""

from typing import Tuple, List, Optional
import os
from .ontology import Ontology
from .obo_parser import parse_obo_file, lookup_obo_term


class EMPTY(Ontology):
    """
    EMPTY - Experimental Measurements, Purposes, and Treatments ontologY.

    Reads from a local OBO file containing the EMPTY ontology terms.

    File location: common/controlled_vocabulary/empty.obo

    Examples:
        >>> empty = EMPTY()
        >>> id, name, defn, syn = empty.lookup_term_or_id('00000090')
        >>> print(name)
        'behavioral measurement'
        >>> id, name, defn, syn = empty.lookup_term_or_id('Behavioral measurement')
        >>> print(id)
        'EMPTY:00000090'
    """

    # Class-level cache for EMPTY OBO data
    _empty_data_cache: Optional[List] = None

    def __init__(self):
        """Constructor for EMPTY ontology."""
        super().__init__()

    def lookup_term_or_id(self, term_or_id_or_name: str) -> Tuple[str, str, str, List[str]]:
        """
        Look up a term in the EMPTY ontology OBO file by ID or name.

        Args:
            term_or_id_or_name: Part after 'EMPTY:' prefix has been removed
                               Can be:
                               - Numeric ID (e.g., '00000090')
                               - Prefixed ID (e.g., 'EMPTY:00000090')
                               - Term name (e.g., 'Behavioral measurement')

        Returns:
            Tuple of (id, name, definition, synonyms) where:
            - id: The full term ID with prefix (e.g., 'EMPTY:00000090')
            - name: The canonical name from the ontology
            - definition: The term definition
            - synonyms: List of synonym strings

        Raises:
            ValueError: If term not found or multiple matches

        Example:
            >>> empty = EMPTY()
            >>> id, name, defn, syn = empty.lookup_term_or_id('00000090')
            >>> print(name)
            'behavioral measurement'
        """
        # Get cached OBO data
        empty_data = self._get_empty_data()
        original_input = term_or_id_or_name

        # Determine if input is an ID or name
        term_id = None
        term_name = None

        # Check if it looks like a numeric ID
        if term_or_id_or_name.isdigit():
            # Numeric ID - prepend prefix
            term_id = f'EMPTY:{term_or_id_or_name}'

        elif term_or_id_or_name.upper().startswith('EMPTY:'):
            # Already has prefix
            term_id = term_or_id_or_name

        else:
            # Assume it's a name
            term_name = term_or_id_or_name

        # Perform lookup
        try:
            if term_id:
                id_val, name, definition, synonyms = lookup_obo_term(empty_data, term_id=term_id)
            else:
                id_val, name, definition, synonyms = lookup_obo_term(empty_data, term_name=term_name)

            return id_val, name, definition, synonyms

        except ValueError as e:
            # Re-raise with more context
            raise ValueError(f'EMPTY lookup failed for "{original_input}": {str(e)}') from e

    @classmethod
    def _get_empty_data(cls) -> List:
        """
        Load/cache EMPTY OBO data from file.

        Returns:
            List of term dictionaries from OBO file

        Raises:
            FileNotFoundError: If OBO file not found
            ValueError: If file format is invalid
        """
        if cls._empty_data_cache is None:
            print('Loading EMPTY ontology from OBO file...')

            # Get file path using constants
            from ..common import PathConstants
            obo_file_path = os.path.join(
                PathConstants.common_folder(),
                Ontology.ONTOLOGY_SUBFOLDER_NDIC,  # controlled_vocabulary
                'empty.obo'
            )

            if not os.path.isfile(obo_file_path):
                raise FileNotFoundError(f'EMPTY ontology OBO file not found at: {obo_file_path}')

            try:
                cls._empty_data_cache = parse_obo_file(obo_file_path)
                print(f'EMPTY ontology loaded successfully ({len(cls._empty_data_cache)} terms).')

            except Exception as e:
                cls._empty_data_cache = None
                raise ValueError(f'Failed to load EMPTY ontology from "{obo_file_path}": {str(e)}') from e

        return cls._empty_data_cache

    @classmethod
    def clear_cache(cls):
        """Clear the EMPTY data cache."""
        cls._empty_data_cache = None

    def __repr__(self) -> str:
        """String representation."""
        return "EMPTY()"
