"""Convert related publications information to Crossref format.

This module converts related publications information from NDI Cloud format
to the Crossref Relations Program format.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertRelatedPublications.m
"""

from typing import Dict, Any, List, Optional


def convert_related_publications(
    cloud_dataset: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """Convert related publications to Crossref Relations Program format.

    Extracts related publications information from the dataset and converts it
    to the Crossref REL Program structure. This allows linking datasets to
    associated publications.

    Args:
        cloud_dataset: Dictionary containing dataset metadata with optional
            'associatedPublications' field. This field should be a list of
            publication information dictionaries.

    Returns:
        Dictionary representing REL Program with related items, or None if no
        associated publications are specified. The structure includes:
        - related_item: List of related item dictionaries

        Returns None if associatedPublications field is missing or empty.

    Note:
        Ported from MATLAB:
        ndi/+ndi/+cloud/+admin/+crossref/+conversion/convertRelatedPublications.m

        This is currently a placeholder implementation. The MATLAB version
        includes a TODO to fill in relevant information from relPublicationDetails.
        Additional fields that could be included:
        - DOI of related publication
        - Title
        - Authors
        - Publication date
        - Relationship type (e.g., 'isSupplementTo', 'isCitedBy')

    Example:
        >>> dataset = {
        ...     'associatedPublications': [
        ...         {'doi': '10.1234/example', 'title': 'Related Paper'},
        ...         {'doi': '10.5678/another', 'title': 'Another Paper'}
        ...     ]
        ... }
        >>> result = convert_related_publications(dataset)
        >>> print(len(result['related_item']))
        2
        >>>
        >>> # With no publications
        >>> dataset = {}
        >>> result = convert_related_publications(dataset)
        >>> print(result)
        None
    """
    # Check if associatedPublications field exists and is not empty
    if ('associatedPublications' not in cloud_dataset or
            not cloud_dataset['associatedPublications']):
        return None

    rel_publication_details = cloud_dataset['associatedPublications']

    # Create related items list
    rel_item_list = []

    for publication in rel_publication_details:
        # TODO: This is a placeholder. Update by filling in relevant info
        # from rel_publication_details
        # Possible fields to include:
        # - inter_work_relation (relationship type)
        # - intra_work_relation (internal relationship)
        # - DOI
        # - Title
        # - Contributors
        # - Publication date

        rel_item = _create_related_item_placeholder(publication)
        rel_item_list.append(rel_item)

    # Create REL Program object
    rel_program_obj = {
        'related_item': rel_item_list
    }

    return rel_program_obj


def _create_related_item_placeholder(publication: Dict[str, Any]) -> Dict[str, Any]:
    """Create a placeholder related item structure.

    This is a helper function to create a basic related item structure.
    In a full implementation, this would extract and format all relevant
    publication metadata.

    Args:
        publication: Publication information dictionary

    Returns:
        Dictionary representing a related item
    """
    rel_item = {
        'description': 'Related publication (placeholder)',
        # TODO: Add actual fields from publication
    }

    # If DOI is available, include it
    if 'doi' in publication and publication['doi']:
        rel_item['doi'] = publication['doi']

    # If title is available, include it
    if 'title' in publication and publication['title']:
        rel_item['title'] = publication['title']

    return rel_item


# Object-oriented approach (alternative implementation)

class RelRelatedItem:
    """Related item for Crossref Relations Program.

    Attributes:
        doi: DOI of related publication (optional)
        title: Title of related publication (optional)
        relationship_type: Type of relationship (optional)
        description: Description of relationship (optional)
    """

    def __init__(
        self,
        doi: Optional[str] = None,
        title: Optional[str] = None,
        relationship_type: Optional[str] = None,
        description: Optional[str] = None
    ):
        """Initialize RelRelatedItem.

        Args:
            doi: DOI string
            title: Title string
            relationship_type: Relationship type (e.g., 'isSupplementTo')
            description: Description text
        """
        self.doi = doi
        self.title = title
        self.relationship_type = relationship_type
        self.description = description

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary.

        Returns:
            Dictionary with available fields
        """
        result = {}

        if self.doi:
            result['doi'] = self.doi
        if self.title:
            result['title'] = self.title
        if self.relationship_type:
            result['relationship_type'] = self.relationship_type
        if self.description:
            result['description'] = self.description

        return result


class RelProgram:
    """Relations Program for Crossref.

    Attributes:
        related_item: List of RelRelatedItem objects
    """

    def __init__(self, related_item: List[RelRelatedItem]):
        """Initialize RelProgram.

        Args:
            related_item: List of RelRelatedItem objects
        """
        self.related_item = related_item

    def to_dict(self) -> Dict[str, List[Dict[str, Any]]]:
        """Convert to dictionary.

        Returns:
            Dictionary with related_item list
        """
        return {
            'related_item': [item.to_dict() for item in self.related_item]
        }


def convert_related_publications_object(
    cloud_dataset: Dict[str, Any]
) -> Optional[RelProgram]:
    """Convert related publications to RelProgram object.

    Alternative to convert_related_publications() that returns a RelProgram
    object instead of a dictionary.

    Args:
        cloud_dataset: Cloud dataset dictionary with associatedPublications

    Returns:
        RelProgram object or None if no publications

    Example:
        >>> dataset = {'associatedPublications': [{'doi': '10.1234/example'}]}
        >>> rel_program = convert_related_publications_object(dataset)
        >>> print(rel_program.related_item[0].doi)
        '10.1234/example'
    """
    rel_dict = convert_related_publications(cloud_dataset)

    if rel_dict is None:
        return None

    # Create RelRelatedItem objects
    related_items = []
    for item_dict in rel_dict['related_item']:
        item = RelRelatedItem(
            doi=item_dict.get('doi'),
            title=item_dict.get('title'),
            description=item_dict.get('description')
        )
        related_items.append(item)

    rel_program = RelProgram(related_item=related_items)

    return rel_program


# Common relationship types for Crossref
RELATIONSHIP_TYPES = {
    'is_supplement_to': 'isSupplementTo',
    'is_supplemented_by': 'isSupplementedBy',
    'is_cited_by': 'isCitedBy',
    'cites': 'cites',
    'is_preprint_of': 'isPreprintOf',
    'has_preprint': 'hasPreprint',
    'is_version_of': 'isVersionOf',
    'has_version': 'hasVersion',
    'is_part_of': 'isPartOf',
    'has_part': 'hasPart',
}


def create_related_item(
    doi: Optional[str] = None,
    title: Optional[str] = None,
    relationship: str = 'is_supplement_to',
    **kwargs
) -> Dict[str, Any]:
    """Create a properly formatted related item dictionary.

    Helper function to create a related item with common fields.

    Args:
        doi: DOI of related publication
        title: Title of related publication
        relationship: Relationship type (key from RELATIONSHIP_TYPES)
        **kwargs: Additional fields to include

    Returns:
        Dictionary representing a related item

    Example:
        >>> item = create_related_item(
        ...     doi='10.1234/example',
        ...     title='Related Paper',
        ...     relationship='is_supplement_to'
        ... )
        >>> print(item['doi'])
        '10.1234/example'
    """
    item = {}

    if doi:
        item['doi'] = doi
    if title:
        item['title'] = title

    # Map relationship type
    rel_type = RELATIONSHIP_TYPES.get(relationship, relationship)
    item['relationship_type'] = rel_type

    # Add any additional fields
    item.update(kwargs)

    return item
