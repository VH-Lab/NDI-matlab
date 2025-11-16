"""
NDI Ontology - Base class for ontology objects and lookup operations.

This module provides static methods for ontology lookups and data management,
and defines the interface for specific ontology subclass lookups.
"""

from typing import Tuple, Dict, List, Any, Optional
import re
import os
import json
import urllib.parse
import urllib.request
from abc import ABC, abstractmethod


class Ontology(ABC):
    """
    Base class for NDI ontology objects and lookup operations.

    Provides static methods for ontology lookups and data management,
    and defines the interface for specific ontology subclass lookups.

    Usage:
        Typically, users interact with the static lookup method:
        id, name, prefix, defn, syn = Ontology.lookup('PREFIX:TermOrID')

        This static method determines the correct ontology subclass based on PREFIX,
        instantiates it, and calls the specific lookup_term_or_id method implemented
        by that subclass.

    Caching:
        For efficiency, this class uses a centralized cache within the main
        'lookup' method. After a term is looked up once, its results are stored,
        and subsequent lookups for the same term are served instantly from memory,
        avoiding redundant file parsing or web requests.

        To force the system to re-read all cached data, use clearCache():
            Ontology.clear_cache()

    Examples:
        >>> # Look up a Cell Ontology term
        >>> id, name, prefix, defn, syn, short = Ontology.lookup('CL:0000000')
        >>> # Look up a local NDIC term
        >>> id, name, prefix, defn, syn, short = Ontology.lookup('NDIC:8')
    """

    # Constants
    ONTOLOGY_FILENAME = 'ontology_list.json'
    ONTOLOGY_SUBFOLDER_JSON = 'ontology'
    ONTOLOGY_SUBFOLDER_NDIC = 'controlled_vocabulary'
    NDIC_FILENAME = 'NDIC.txt'

    # Class-level caches
    _lookup_cache: Dict[str, Dict[str, Any]] = {}
    _lookup_keys: List[str] = []
    _cache_size = 100
    _obo_data_cache: Dict[str, List[Dict]] = {}
    _ontology_json_data: Optional[Dict] = None

    def __init__(self):
        """
        Constructor for the base ontology class.

        Does not require arguments. Intended primarily for subclassing.
        """
        pass

    @abstractmethod
    def lookup_term_or_id(self, term_or_id_or_name: str) -> Tuple[str, str, str, List[str]]:
        """
        Base implementation for looking up a term within a specific ontology instance.

        Args:
            term_or_id_or_name: The 'remainder' after the prefix has been stripped
                               by the main static lookup() function
                               (e.g., '0000000' for CL, 'metre' for OM)

        Returns:
            Tuple of (id, name, definition, synonyms) where:
            - id: Term ID (e.g., 'CL:0000000')
            - name: Term name
            - definition: Term definition
            - synonyms: List of synonyms

        Notes:
            This base implementation returns empty values and issues a warning.
            Subclasses should override this method.
        """
        import warnings
        warnings.warn(
            f'lookup_term_or_id called on the base Ontology class for input "{term_or_id_or_name}". '
            'Subclass should override this method. Returning empty.',
            UserWarning
        )
        return '', '', '', []

    # Static methods for ontology lookup

    @classmethod
    def lookup(cls, lookup_string: str) -> Tuple[str, str, str, str, List[str], str]:
        """
        Look up a term in an ontology using a prefixed string.

        Args:
            lookup_string: Prefixed string (e.g., 'CL:0000000', 'OM:metre')
                          or 'clear' to clear the cache

        Returns:
            Tuple of (id, name, prefix, definition, synonyms, short_name) where:
            - id: Term ID
            - name: Term name
            - prefix: Ontology prefix
            - definition: Term definition
            - synonyms: List of synonyms
            - short_name: Variable-safe name

        Examples:
            >>> id, name, prefix, defn, syn, short = Ontology.lookup('CL:0000000')
            >>> # Clear cache
            >>> Ontology.lookup('clear')
        """
        # Handle cache clearing request
        if lookup_string == 'clear':
            cls._lookup_cache = {}
            cls._lookup_keys = []
            return '', '', '', '', [], ''

        # Check cache first
        if lookup_string in cls._lookup_cache:
            result = cls._lookup_cache[lookup_string]
            # Update LRU order
            if lookup_string in cls._lookup_keys:
                cls._lookup_keys.remove(lookup_string)
            cls._lookup_keys.append(lookup_string)
            return (
                result['id'],
                result['name'],
                result['prefix'],
                result['definition'],
                result['synonyms'],
                result['short_name']
            )

        # Cache miss - proceed with full lookup
        id_val = ''
        name = ''
        prefix = ''
        definition = ''
        synonyms = []
        short_name = ''

        # 1. Get ontology name and remainder from prefix
        try:
            ontology_name, remainder = cls.get_ontology_name_from_prefix(lookup_string)
            if not ontology_name:
                raise ValueError(f'Failed to map prefix from "{lookup_string}" to a known ontology name.')
        except Exception as e:
            raise ValueError(f'Error processing prefix for input "{lookup_string}": {str(e)}') from e

        # 2. Extract prefix for output
        colon_pos = lookup_string.find(':')
        if colon_pos == -1:
            raise ValueError(f'Input string "{lookup_string}" lacks the required "prefix:term" format for lookup.')
        prefix = lookup_string[:colon_pos].strip()

        # 3. Construct specific class name and instantiate object
        # Import the specific ontology module
        class_name = ontology_name
        try:
            # Import from ontology submodule
            from . import NDIC, CL, CHEBI, PATO, OM, Uberon, NCBITaxon, NCIT, NCIm, PubChem, RRID, WBStrain, EMPTY

            class_map = {
                'NDIC': NDIC,
                'CL': CL,
                'CHEBI': CHEBI,
                'PATO': PATO,
                'OM': OM,
                'Uberon': Uberon,
                'NCBITaxon': NCBITaxon,
                'NCIT': NCIT,
                'NCIm': NCIm,
                'PubChem': PubChem,
                'RRID': RRID,
                'WBStrain': WBStrain,
                'EMPTY': EMPTY
            }

            if class_name not in class_map:
                raise ValueError(f'Unknown ontology class: {class_name}')

            ontology_obj = class_map[class_name]()

        except Exception as e:
            raise ValueError(f'Failed to instantiate ontology class "{class_name}": {str(e)}') from e

        # 4. Call the instance method lookup_term_or_id
        try:
            id_val, name, definition, synonyms = ontology_obj.lookup_term_or_id(remainder)
        except Exception as e:
            raise ValueError(
                f'Error occurred during lookup_term_or_id call for class "{class_name}" '
                f'with input remainder "{remainder}": {str(e)}'
            ) from e

        # Sanitize synonyms output
        if not isinstance(synonyms, list):
            synonyms = []
        # Flatten and remove empties
        synonyms = [s for s in synonyms if s]

        # 5. Create short_name
        from ..fun import name2variableName
        short_name = name2variableName(name)

        # Store result in cache
        new_result = {
            'id': id_val,
            'name': name,
            'prefix': prefix,
            'definition': definition,
            'synonyms': synonyms,
            'short_name': short_name
        }

        cls._lookup_cache[lookup_string] = new_result
        cls._lookup_keys.append(lookup_string)

        # Enforce cache size limit (LRU)
        if len(cls._lookup_keys) > cls._cache_size:
            key_to_remove = cls._lookup_keys.pop(0)
            del cls._lookup_cache[key_to_remove]

        return id_val, name, prefix, definition, synonyms, short_name

    @classmethod
    def clear_cache(cls):
        """
        Clear all persistent caches in the ontology class.

        This includes:
        - Centralized lookup cache
        - OBO file data cache
        - JSON ontology data cache
        """
        cls._lookup_cache = {}
        cls._lookup_keys = []
        cls._obo_data_cache = {}
        cls._ontology_json_data = None
        print('NDI ontology caches cleared.')

    @classmethod
    def get_ontology_name_from_prefix(cls, ontology_string: str) -> Tuple[str, str]:
        """
        Extract prefix, map to ontology name (case-insensitive).

        Args:
            ontology_string: String with format 'PREFIX:term' or just 'PREFIX'

        Returns:
            Tuple of (ontology_name, remainder) where:
            - ontology_name: Name of the ontology class
            - remainder: Part after the colon

        Raises:
            ValueError: If prefix cannot be extracted or is not found
        """
        prefix = ''
        remainder = ''

        colon_pos = ontology_string.find(':')
        if colon_pos == -1:
            prefix = ontology_string.strip()
            remainder = ''
        else:
            prefix = ontology_string[:colon_pos].strip()
            remainder = ontology_string[colon_pos+1:].strip() if colon_pos < len(ontology_string) - 1 else ''

        if not prefix:
            raise ValueError(f'Could not extract prefix from "{ontology_string}".')

        # Load ontology data
        ontology_data = cls._load_ontology_json_data()

        # Find mapping (case-insensitive)
        ontology_name = ''
        if 'prefix_ontology_mappings' in ontology_data:
            mappings = ontology_data['prefix_ontology_mappings']
            for mapping in mappings:
                if mapping.get('prefix', '').upper() == prefix.upper():
                    ontology_name = mapping.get('ontology_name', '')
                    break

        if not ontology_name:
            raise ValueError(f'Prefix "{prefix}" not found in ontology mappings file.')

        return ontology_name, remainder

    @classmethod
    def _load_ontology_json_data(cls, force_reload: bool = False) -> Dict:
        """
        Load ontology list from JSON, uses class-level cache.

        Args:
            force_reload: Force reload from disk

        Returns:
            Dictionary with ontology data
        """
        if force_reload:
            cls._ontology_json_data = None

        if cls._ontology_json_data is None:
            # Get path using path constants
            from ..common import PathConstants
            file_path = os.path.join(
                PathConstants.common_folder(),
                cls.ONTOLOGY_SUBFOLDER_JSON,
                cls.ONTOLOGY_FILENAME
            )

            if not os.path.isfile(file_path):
                raise FileNotFoundError(f'Ontology list JSON file not found: {file_path}')

            try:
                with open(file_path, 'r') as f:
                    data = json.load(f)

                if 'prefix_ontology_mappings' not in data or 'Ontologies' not in data:
                    raise ValueError(f'Ontology list JSON file "{file_path}" has an invalid format.')

                cls._ontology_json_data = data
                print('NDI ontology list loaded successfully.')

            except Exception as e:
                cls._ontology_json_data = None
                raise ValueError(f'Failed to load or decode ontology list JSON file "{file_path}": {str(e)}') from e

        return cls._ontology_json_data

    # Helper methods for OLS API access (used by web-based ontologies)

    @staticmethod
    def perform_iri_lookup(term_iri: str, ontology_name_ols: str, ontology_prefix: str) -> Tuple[str, str, str, List[str]]:
        """
        Fetch ontology term details from EBI OLS using its IRI.

        Args:
            term_iri: Term IRI
            ontology_name_ols: Ontology name in OLS
            ontology_prefix: Ontology prefix (e.g., 'CL', 'PATO')

        Returns:
            Tuple of (id, name, definition, synonyms)
        """
        # Double URL encode the IRI
        encoded_iri_once = urllib.parse.quote(term_iri, safe='')
        encoded_iri_twice = urllib.parse.quote(encoded_iri_once, safe='')

        # Build OLS URL
        ols_base_url = 'https://www.ebi.ac.uk/ols4/api/ontologies/'
        url = f'{ols_base_url}{ontology_name_ols}/terms/{encoded_iri_twice}'

        # Make request
        try:
            req = urllib.request.Request(url)
            req.add_header('Accept', 'application/json')

            with urllib.request.urlopen(req, timeout=30) as response:
                data = json.loads(response.read().decode())

            if not data:
                raise ValueError(f'Received invalid/empty response from OLS Term API for ontology "{ontology_name_ols}", IRI "{term_iri}".')

            # Extract ID
            id_val = ''
            if 'obo_id' in data and data['obo_id']:
                if data['obo_id'].upper().startswith(f'{ontology_prefix}:'.upper()):
                    id_val = data['obo_id']
            elif 'short_form' in data and data['short_form']:
                id_temp = data['short_form']
                # Handle underscore format
                if id_temp.upper().startswith(f'{ontology_prefix}_'.upper()):
                    id_val = id_temp.replace('_', ':', 1)
                elif id_temp.isdigit():
                    id_val = f'{ontology_prefix}:{id_temp}'
                elif id_temp.upper().startswith(f'{ontology_prefix}:'.upper()):
                    id_val = id_temp

            # Extract name
            name = data.get('label', '')

            # Extract definition
            definition = ''
            if 'description' in data and data['description']:
                if isinstance(data['description'], list):
                    non_empty = [d for d in data['description'] if d]
                    if non_empty:
                        definition = non_empty[0]

            # Extract synonyms
            synonyms = []
            if 'obo_synonym' in data and data['obo_synonym']:
                if isinstance(data['obo_synonym'], list):
                    for syn in data['obo_synonym']:
                        if isinstance(syn, dict):
                            syn_name = syn.get('name') or syn.get('label', '')
                            if syn_name:
                                synonyms.append(syn_name)

            return id_val, name, definition, synonyms

        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise ValueError(f'IRI "{term_iri}" not found via OLS Term API for ontology "{ontology_name_ols}" (404 Error).')
            raise ValueError(f'OLS Term API request failed for IRI "{term_iri}", ontology "{ontology_name_ols}": HTTP {e.code}') from e
        except urllib.error.URLError as e:
            if 'timed out' in str(e):
                raise ValueError(f'OLS Term API timeout for IRI "{term_iri}", ontology "{ontology_name_ols}".')
            raise ValueError(f'OLS Term API request failed for IRI "{term_iri}", ontology "{ontology_name_ols}": {str(e)}') from e

    @staticmethod
    def search_ols_and_perform_iri_lookup(search_query: str, search_field: str,
                                          ontology_name_ols: str, ontology_prefix: str,
                                          lookup_type_msg: str) -> Tuple[str, str, str, List[str]]:
        """
        Search OLS and look up unique result by IRI.

        Args:
            search_query: Query string
            search_field: Field to search ('obo_id' or 'label')
            ontology_name_ols: Ontology name in OLS
            ontology_prefix: Ontology prefix
            lookup_type_msg: Description for error messages

        Returns:
            Tuple of (id, name, definition, synonyms)
        """
        # Build search URL
        ols_search_url = 'https://www.ebi.ac.uk/ols4/api/search'

        # Build query parameters
        params = {
            'q': search_query,
            'ontology': ontology_name_ols,
            'queryFields': search_field
        }

        # Add exact=true for ID searches
        if search_field == 'obo_id':
            params['exact'] = 'true'

        # URL encode parameters
        query_string = urllib.parse.urlencode(params)
        url = f'{ols_search_url}?{query_string}'

        # Make request
        try:
            req = urllib.request.Request(url)
            req.add_header('Accept', 'application/json')

            with urllib.request.urlopen(req, timeout=30) as response:
                search_response = json.loads(response.read().decode())

            if 'response' not in search_response or 'numFound' not in search_response['response']:
                raise ValueError(f'Invalid search response structure from OLS for {lookup_type_msg} in "{ontology_name_ols}".')

            num_found = search_response['response']['numFound']

            if num_found == 0:
                raise ValueError(f'Term matching {lookup_type_msg} not found in "{ontology_name_ols}" via OLS search.')

            elif num_found == 1:
                doc = search_response['response']['docs'][0]

                # For label searches, verify exact match
                if search_field == 'label':
                    if 'label' not in doc or doc['label'].lower() != search_query.lower():
                        raise ValueError(f'Search for name "{search_query}" returned single result with non-matching label.')

                # Extract IRI
                if 'iri' not in doc or not doc['iri']:
                    raise ValueError(f'Found unique term for {lookup_type_msg}, but could not extract IRI.')

                term_iri = doc['iri']

            else:  # num_found > 1
                # For label searches, try to find exact match
                if search_field == 'label':
                    docs = search_response['response']['docs']
                    exact_matches = [d for d in docs if d.get('label', '').lower() == search_query.lower()]

                    if len(exact_matches) == 1:
                        term_iri = exact_matches[0]['iri']
                    elif len(exact_matches) == 0:
                        raise ValueError(f'No exact (case-insensitive) label match for "{search_query}" found among {num_found} results in "{ontology_name_ols}".')
                    else:
                        raise ValueError(f'Term matching {lookup_type_msg} resulted in {len(exact_matches)} exact matches (case-insensitive) in "{ontology_name_ols}". Requires unique match.')
                else:
                    raise ValueError(f'Term matching {lookup_type_msg} yielded {num_found} results in "{ontology_name_ols}" (expected 1 for ID search).')

            # Perform IRI lookup
            return Ontology.perform_iri_lookup(term_iri, ontology_name_ols, ontology_prefix)

        except urllib.error.URLError as e:
            if 'timed out' in str(e):
                raise ValueError(f'OLS API search timed out for {lookup_type_msg} in "{ontology_name_ols}".')
            raise ValueError(f'OLS API search failed for {lookup_type_msg} in "{ontology_name_ols}": {str(e)}') from e

    @staticmethod
    def preprocess_lookup_input(term_or_id_or_name: str, ontology_prefix: str) -> Tuple[str, str, str, str]:
        """
        Process input for ontology lookup functions.

        Handles standard prefix/ID/name logic and OM-specific heuristic.

        Args:
            term_or_id_or_name: Input term/ID/name (without ontology prefix)
            ontology_prefix: Ontology prefix (e.g., 'CL', 'OM')

        Returns:
            Tuple of (search_query, search_field, lookup_type_msg, original_input)
        """
        original_input = term_or_id_or_name
        processed_input = original_input.strip()
        prefix_with_colon = f'{ontology_prefix}:'
        is_om_ontology = ontology_prefix.upper() == 'OM'

        if is_om_ontology:
            # Special handling for OM - no numeric IDs supported
            if re.match(r'^\d+$', processed_input):
                raise ValueError(f'Lookup by purely numeric ID ("{original_input}") is not supported for OM.')

            term_component = ''
            if processed_input.upper().startswith(prefix_with_colon.upper()):
                remainder = processed_input[len(prefix_with_colon):].strip()
                if re.match(r'^\d+$', remainder):
                    raise ValueError(f'Lookup by prefixed numeric ID ("{original_input}") is not supported for OM.')
                elif not remainder:
                    raise ValueError(f'Input "{original_input}" has prefix "{prefix_with_colon}" but is missing term component.')
                else:
                    term_component = remainder
            else:
                term_component = processed_input

            # Convert to likely label (camelCase to lowercase with spaces)
            likely_label = re.sub(r'([a-z])([A-Z])', r'\1 \2', term_component).lower().strip()

            search_query = likely_label
            search_field = 'label'
            lookup_type_msg = f'input "{original_input}" (searching label as "{likely_label}")'

        else:
            # Standard handling
            if processed_input.upper().startswith(prefix_with_colon.upper()):
                remainder = processed_input[len(prefix_with_colon):].strip()
                if re.match(r'^\d+$', remainder):
                    # Prefixed numeric ID
                    search_query = f'{ontology_prefix}:{remainder}'
                    search_field = 'obo_id'
                    lookup_type_msg = f'prefixed ID "{original_input}"'
                elif not remainder:
                    raise ValueError(f'Input "{original_input}" has prefix "{prefix_with_colon}" but is missing term/ID.')
                else:
                    # Prefixed name
                    search_query = remainder
                    search_field = 'label'
                    lookup_type_msg = f'prefixed name "{original_input}"'
            elif re.match(r'^\d+$', processed_input):
                # Numeric ID
                search_query = f'{ontology_prefix}:{processed_input}'
                search_field = 'obo_id'
                lookup_type_msg = f'numeric ID "{original_input}"'
            else:
                # Name
                search_query = processed_input
                search_field = 'label'
                lookup_type_msg = f'name "{original_input}"'

        return search_query, search_field, lookup_type_msg, original_input

    def __repr__(self) -> str:
        """String representation."""
        return f"{self.__class__.__name__}()"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
