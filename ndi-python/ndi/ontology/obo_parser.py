"""
OBO File Parser for NDI Ontologies.

This module provides functionality to parse OBO (Open Biomedical Ontologies) format files.
OBO is a simple text-based format for representing ontologies.

OBO Format Specification: https://owlcollab.github.io/oboformat/doc/GO.format.obo-1_4.html
"""

from typing import Dict, List, Tuple
import re


def parse_obo_file(file_path: str) -> List[Dict[str, any]]:
    """
    Parse an OBO format file and return a list of term dictionaries.

    Args:
        file_path: Path to the OBO file

    Returns:
        List of term dictionaries, each containing:
        - id: Term ID (e.g., 'EMPTY:00000090')
        - name: Term name
        - def: Definition text (without trailing [])
        - namespace: Namespace (if present)
        - synonyms: List of synonym strings
        - is_a: List of parent term IDs

    Raises:
        FileNotFoundError: If file doesn't exist
        ValueError: If file format is invalid

    Example:
        >>> terms = parse_obo_file('empty.obo')
        >>> term = [t for t in terms if t['id'] == 'EMPTY:00000090'][0]
        >>> print(term['name'])
        'behavioral measurement'
    """
    terms = []
    current_term = None

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()

                # Skip empty lines
                if not line:
                    continue

                # Start of a new term
                if line == '[Term]':
                    if current_term is not None:
                        terms.append(current_term)
                    current_term = {
                        'id': '',
                        'name': '',
                        'def': '',
                        'namespace': '',
                        'synonyms': [],
                        'is_a': []
                    }
                    continue

                # End of term section (new stanza type)
                if line.startswith('[') and line != '[Term]':
                    if current_term is not None:
                        terms.append(current_term)
                        current_term = None
                    continue

                # Skip if not in a term
                if current_term is None:
                    continue

                # Parse term properties
                if ':' not in line:
                    continue

                # Split on first colon
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                if key == 'id':
                    current_term['id'] = value

                elif key == 'name':
                    current_term['name'] = value

                elif key == 'namespace':
                    current_term['namespace'] = value

                elif key == 'def':
                    # Extract definition text (remove trailing [] and quotes)
                    # Format: def: "definition text" [ref1, ref2]
                    match = re.match(r'"(.+?)"', value)
                    if match:
                        current_term['def'] = match.group(1)
                    else:
                        current_term['def'] = value

                elif key == 'synonym':
                    # Extract synonym text from quotes
                    # Format: synonym: "synonym text" SCOPE [refs]
                    match = re.match(r'"(.+?)"', value)
                    if match:
                        current_term['synonyms'].append(match.group(1))

                elif key == 'is_a':
                    # Extract parent term ID (everything before comment)
                    parent_id = value.split('!')[0].strip()
                    current_term['is_a'].append(parent_id)

            # Don't forget the last term
            if current_term is not None:
                terms.append(current_term)

    except FileNotFoundError:
        raise FileNotFoundError(f'OBO file not found: {file_path}')
    except Exception as e:
        raise ValueError(f'Error parsing OBO file "{file_path}": {str(e)}') from e

    return terms


def lookup_obo_term(terms: List[Dict], term_id: str = None, term_name: str = None) -> Tuple[str, str, str, List[str]]:
    """
    Look up a term in parsed OBO data by ID or name.

    Args:
        terms: List of term dictionaries from parse_obo_file()
        term_id: Term ID to search for (e.g., 'EMPTY:00000090')
        term_name: Term name to search for (case-insensitive)

    Returns:
        Tuple of (id, name, definition, synonyms)

    Raises:
        ValueError: If term not found or multiple matches

    Example:
        >>> terms = parse_obo_file('empty.obo')
        >>> id, name, defn, syn = lookup_obo_term(terms, term_id='EMPTY:00000090')
        >>> print(name)
        'behavioral measurement'
    """
    matching_terms = []

    if term_id:
        # Search by ID (case-sensitive)
        matching_terms = [t for t in terms if t['id'] == term_id]

    elif term_name:
        # Search by name (case-insensitive)
        matching_terms = [t for t in terms if t['name'].lower() == term_name.lower()]

    else:
        raise ValueError('Must provide either term_id or term_name')

    if len(matching_terms) == 0:
        if term_id:
            raise ValueError(f'Term with ID "{term_id}" not found in OBO data')
        else:
            raise ValueError(f'Term with name "{term_name}" not found in OBO data')

    elif len(matching_terms) > 1:
        raise ValueError(f'Multiple terms found matching query (found {len(matching_terms)})')

    term = matching_terms[0]
    return term['id'], term['name'], term['def'], term['synonyms']
