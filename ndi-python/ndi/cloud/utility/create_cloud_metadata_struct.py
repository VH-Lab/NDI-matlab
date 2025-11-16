"""
Create cloud metadata structure for dataset upload.

This module converts a metadata structure from the MetadataEditorApp format
to the cloud API format required for dataset creation.

MATLAB Source: ndi/+ndi/+cloud/+utility/createCloudMetadataStruct.m
"""

from typing import Dict, Any
import warnings


def create_cloud_metadata_struct(metadata_struct: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create cloud metadata structure from MetadataEditorApp data.

    This function applies the MetaDataEditorApp data structure to create
    metadata formatted for the NDI Cloud API. It transforms the input metadata
    structure into the format required by the cloud API for dataset creation.

    Note: This function does not create any ndi.document representations
    of the metadata, but only formats the metadata for the cloud API.

    Args:
        metadata_struct: A dictionary with the metadata to convert. Must be
            a valid metadata structure as validated by must_be_valid_metadata().

    Returns:
        A dictionary containing cloud-formatted metadata with fields like:
            - name: Dataset full name
            - abstract: Dataset description
            - branchName: Dataset short name
            - contributors: List of author information
            - correspondingAuthors: List of corresponding authors
            - doi: Digital Object Identifier (placeholder)
            - funding: Funding information
            - license: License information
            - species: Species list
            - numberOfSubjects: Number of subjects
            - associatedPublications: Related publications

    Raises:
        ValueError: If the metadata structure is invalid

    Example:
        >>> from ndi.cloud.utility import create_cloud_metadata_struct
        >>> metadata = {
        ...     'DatasetFullName': 'My Dataset',
        ...     'DatasetShortName': 'my-dataset',
        ...     'Description': ['A sample dataset'],
        ...     'Author': [
        ...         {
        ...             'givenName': 'John',
        ...             'familyName': 'Doe',
        ...             'authorRole': 'Corresponding',
        ...             'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
        ...         }
        ...     ]
        ... }
        >>> cloud_metadata = create_cloud_metadata_struct(metadata)

    Warning:
        Currently fills in a placeholder DOI as DOI generation is not
        yet fully implemented.

    MATLAB Source Reference:
        ndi/+ndi/+cloud/+utility/createCloudMetadataStruct.m
    """
    from .must_be_valid_metadata import must_be_valid_metadata

    # Validate the metadata structure
    must_be_valid_metadata(metadata_struct)

    result = {}

    # Dataset name
    if 'DatasetFullName' in metadata_struct:
        result['name'] = metadata_struct['DatasetFullName']

    # Dataset description/abstract
    if 'Description' in metadata_struct:
        # Description is a list in the original format
        if isinstance(metadata_struct['Description'], list):
            result['abstract'] = metadata_struct['Description'][0]
        else:
            result['abstract'] = metadata_struct['Description']

    # Branch name (short name)
    result['branchName'] = metadata_struct['DatasetShortName']

    # Authors/Contributors
    if 'Author' in metadata_struct:
        contributors = []
        corresponding_indices = []

        for i, author in enumerate(metadata_struct['Author']):
            contributor = {
                'firstName': author.get('givenName', ''),
                'lastName': author.get('familyName', ''),
                'orchid': author.get('digitalIdentifier', {}).get('identifier', '')
            }
            contributors.append(contributor)

            # Track corresponding authors
            if author.get('authorRole') == 'Corresponding':
                corresponding_indices.append(i)

        result['contributors'] = contributors

        # Set corresponding authors
        if corresponding_indices:
            result['correspondingAuthors'] = [contributors[i] for i in corresponding_indices]

    # DOI - currently a placeholder
    warnings.warn(
        'Filling in a placeholder DOI',
        category=UserWarning,
        stacklevel=2
    )
    result['doi'] = "https://doi.org://10.1000/123456789"

    # Funding information
    if 'Funding' in metadata_struct:
        # Get unique funders
        funders = set()
        for funding_entry in metadata_struct['Funding']:
            if 'funder' in funding_entry:
                funders.add(funding_entry['funder'])

        if funders:
            result['funding'] = {
                'source': ', '.join(sorted(funders))
            }

    # License
    if 'License' in metadata_struct:
        result['license'] = metadata_struct['License']

    # Subjects/Species
    if 'Subjects' in metadata_struct:
        all_species = set()

        for subject in metadata_struct['Subjects']:
            if 'SpeciesList' in subject:
                species_list = subject['SpeciesList']
                # Handle both single species and list of species
                if isinstance(species_list, dict):
                    if 'Name' in species_list:
                        all_species.add(species_list['Name'])
                elif isinstance(species_list, list):
                    for species in species_list:
                        if isinstance(species, dict) and 'Name' in species:
                            all_species.add(species['Name'])

        if all_species:
            result['species'] = ', '.join(sorted(all_species))

        result['numberOfSubjects'] = len(metadata_struct['Subjects'])

    # Related Publications
    if 'RelatedPublication' in metadata_struct:
        publications = []

        for pub in metadata_struct['RelatedPublication']:
            publication = {
                'DOI': pub.get('DOI', ''),
                'title': pub.get('Publication', ''),
                'PMID': pub.get('PMID', ''),
                'PMCID': pub.get('PMCID', '')
            }
            publications.append(publication)

        result['associatedPublications'] = publications

    return result
