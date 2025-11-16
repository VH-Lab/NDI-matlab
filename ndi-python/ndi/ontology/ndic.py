"""
NDI Ontology NDIC - NDI Controlled Vocabulary from local file.

Inherits from Ontology and implements lookup_term_or_id for the NDIC text file.
"""

from typing import Tuple, List, Optional
import os
import pandas as pd
from .ontology import Ontology


class NDIC(Ontology):
    """
    NDIC - NDI Ontology object for the local NDIC controlled vocabulary file.

    Reads from a tab-separated file containing NDI-specific controlled vocabulary.

    File format (TSV):
        Identifier<tab>Name<tab>Description
        8<tab>Postnatal day<tab>A postnatal day...
        ...

    Examples:
        >>> ndic = NDIC()
        >>> id, name, defn, syn = ndic.lookup_term_or_id('8')
        >>> id, name, defn, syn = ndic.lookup_term_or_id('Postnatal day')
    """

    # Class-level cache for NDIC data
    _ndic_data_cache: Optional[pd.DataFrame] = None

    def __init__(self):
        """Constructor for the NDIC ontology object."""
        super().__init__()

    def lookup_term_or_id(self, term_or_id_or_name: str) -> Tuple[str, str, str, List[str]]:
        """
        Look up a term in the NDIC ontology file by ID or name.

        Args:
            term_or_id_or_name: Part after 'NDIC:' prefix has been removed
                               (e.g., '8' or 'Postnatal day')

        Returns:
            Tuple of (id, name, definition, synonyms) where:
            - id: The identifier as string
            - name: The canonical name from the table
            - definition: The description
            - synonyms: Always empty list for NDIC

        Raises:
            ValueError: If term not found or multiple matches
        """
        # Get cached data table
        ndic_data = self._get_ndic_data()
        original_input = term_or_id_or_name

        # Initialize outputs
        id_val = ''
        name = ''
        definition = ''
        synonyms = []

        # Determine if input looks like a numeric ID
        is_numeric_id = False
        input_num = None
        try:
            input_num = float(term_or_id_or_name)
            if input_num.is_integer():
                input_num = int(input_num)
                is_numeric_id = True
        except (ValueError, TypeError):
            is_numeric_id = False

        # Perform lookup
        row_index = None

        if is_numeric_id:
            # Path 1: Lookup by numeric ID
            matches = ndic_data[ndic_data['Identifier'] == input_num]
            if len(matches) == 0:
                raise ValueError(f'NDIC term with Identifier "{original_input}" not found.')
            row_index = matches.index[0]

        else:
            # Path 2: Lookup by name (case-insensitive)
            name_to_lookup = original_input
            matches = ndic_data[ndic_data['Name'].str.lower() == name_to_lookup.lower()]

            if len(matches) == 0:
                raise ValueError(f'NDIC term with Name "{name_to_lookup}" not found (case-insensitive).')
            elif len(matches) > 1:
                raise ValueError(
                    f'Name "{name_to_lookup}" matches multiple ({len(matches)}) entries in NDIC ontology. '
                    'Lookup requires a unique name.'
                )
            else:
                row_index = matches.index[0]

        # Extract data if found
        if row_index is not None:
            try:
                id_val = str(int(ndic_data.loc[row_index, 'Identifier']))  # Return ID as string
                name = str(ndic_data.loc[row_index, 'Name'])  # Return canonical name
                definition = str(ndic_data.loc[row_index, 'Description'])  # Return description
                synonyms = []  # Always empty for NDIC
            except Exception as e:
                raise ValueError(
                    f'Error extracting data for input "{original_input}" at row {row_index}: {str(e)}'
                ) from e

        return id_val, name, definition, synonyms

    @classmethod
    def _get_ndic_data(cls) -> pd.DataFrame:
        """
        Load/cache NDIC data from file.

        Returns:
            DataFrame with columns: Identifier, Name, Description

        Raises:
            FileNotFoundError: If NDIC file not found
            ValueError: If file format is invalid
        """
        if cls._ndic_data_cache is None:
            print('Loading NDIC ontology from file...')

            # Get file path using constants
            from ..common import PathConstants
            ontology_file_path = os.path.join(
                PathConstants.common_folder(),
                Ontology.ONTOLOGY_SUBFOLDER_NDIC,
                Ontology.NDIC_FILENAME
            )

            if not os.path.isfile(ontology_file_path):
                raise FileNotFoundError(f'NDIC ontology file not found at: {ontology_file_path}')

            try:
                # Read TSV file
                loaded_data = pd.read_csv(
                    ontology_file_path,
                    sep='\t',
                    dtype={'Identifier': int, 'Name': str, 'Description': str},
                    keep_default_na=False  # Don't convert empty strings to NaN
                )

                # Verify columns
                required_columns = {'Identifier', 'Name', 'Description'}
                if not required_columns.issubset(loaded_data.columns):
                    raise ValueError(
                        f'NDIC ontology file "{ontology_file_path}" does not contain expected columns: '
                        f'{required_columns}'
                    )

                if len(loaded_data) == 0:
                    raise ValueError(f'NDIC ontology file "{ontology_file_path}" contains no data rows.')

                cls._ndic_data_cache = loaded_data
                print('NDIC ontology loaded successfully.')

            except Exception as e:
                cls._ndic_data_cache = None
                raise ValueError(f'Failed to read or parse NDIC ontology file "{ontology_file_path}": {str(e)}') from e

        return cls._ndic_data_cache

    @classmethod
    def clear_cache(cls):
        """Clear the NDIC data cache."""
        cls._ndic_data_cache = None

    def __repr__(self) -> str:
        """String representation."""
        return "NDIC()"
