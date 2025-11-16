"""
Comprehensive tests for cloud utility module.

Tests create_cloud_metadata_struct, must_be_valid_metadata,
and validation error cases.
"""

import pytest
import warnings
from unittest.mock import Mock, patch

from ndi.cloud.utility.create_cloud_metadata_struct import create_cloud_metadata_struct
from ndi.cloud.utility.must_be_valid_metadata import (
    must_be_valid_metadata,
    check_metadata_cloud_inputs
)


class TestMustBeValidMetadata:
    """Tests for metadata validation functions."""

    def test_valid_metadata_complete(self):
        """Test validating complete valid metadata."""
        metadata = {
            'DatasetFullName': 'My Test Dataset',
            'DatasetShortName': 'test-dataset',
            'Description': ['A comprehensive test dataset'],
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Corresponding',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'CC BY 4.0',
            'Subjects': []
        }

        # Should not raise any exception
        must_be_valid_metadata(metadata)

    def test_valid_metadata_minimal(self):
        """Test validating minimal valid metadata."""
        metadata = {
            'DatasetFullName': 'Minimal Dataset',
            'DatasetShortName': 'minimal',
            'Description': 'Description',
            'Author': [{
                'givenName': 'Jane',
                'familyName': 'Smith',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-1111-2222'}
            }],
            'Funding': [{'funder': 'NIH'}],
            'License': 'MIT',
            'Subjects': []
        }

        must_be_valid_metadata(metadata)

    def test_invalid_metadata_missing_fields(self):
        """Test error when required fields are missing."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            # Missing other required fields
        }

        with pytest.raises(ValueError, match="missing required fields"):
            must_be_valid_metadata(metadata)

    def test_invalid_metadata_missing_author_fields(self):
        """Test error when author fields are incomplete."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Description',
            'Author': [{
                'givenName': 'John',
                # Missing familyName, authorRole, digitalIdentifier
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'CC BY 4.0',
            'Subjects': []
        }

        with pytest.raises(ValueError, match="missing required fields"):
            must_be_valid_metadata(metadata)

    def test_invalid_metadata_missing_digital_identifier(self):
        """Test error when digital identifier is missing."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Description',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Corresponding',
                'digitalIdentifier': {}  # Missing 'identifier' field
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'CC BY 4.0',
            'Subjects': []
        }

        with pytest.raises(ValueError, match="missing required fields"):
            must_be_valid_metadata(metadata)

    def test_invalid_metadata_missing_funding_funder(self):
        """Test error when funding funder is missing."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Description',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Corresponding',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{}],  # Missing 'funder' field
            'License': 'CC BY 4.0',
            'Subjects': []
        }

        with pytest.raises(ValueError, match="missing required fields"):
            must_be_valid_metadata(metadata)

    def test_check_metadata_cloud_inputs_valid(self):
        """Test check_metadata_cloud_inputs returns True for valid metadata."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Description',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Corresponding',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'CC BY 4.0',
            'Subjects': []
        }

        assert check_metadata_cloud_inputs(metadata) is True

    def test_check_metadata_cloud_inputs_invalid(self):
        """Test check_metadata_cloud_inputs returns False for invalid metadata."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            # Missing required fields
        }

        assert check_metadata_cloud_inputs(metadata) is False

    def test_valid_metadata_multiple_authors(self):
        """Test validating metadata with multiple authors."""
        metadata = {
            'DatasetFullName': 'Multi-Author Dataset',
            'DatasetShortName': 'multi-author',
            'Description': 'Dataset with multiple authors',
            'Author': [
                {
                    'givenName': 'John',
                    'familyName': 'Doe',
                    'authorRole': 'Corresponding',
                    'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
                },
                {
                    'givenName': 'Jane',
                    'familyName': 'Smith',
                    'authorRole': 'Creator',
                    'digitalIdentifier': {'identifier': '0000-0001-1111-2222'}
                }
            ],
            'Funding': [{'funder': 'NSF'}],
            'License': 'CC BY 4.0',
            'Subjects': []
        }

        must_be_valid_metadata(metadata)


class TestCreateCloudMetadataStruct:
    """Tests for create_cloud_metadata_struct function."""

    def test_create_metadata_complete(self):
        """Test creating cloud metadata from complete structure."""
        metadata = {
            'DatasetFullName': 'My Research Dataset',
            'DatasetShortName': 'research-dataset',
            'Description': ['A comprehensive research dataset for testing'],
            'Author': [
                {
                    'givenName': 'John',
                    'familyName': 'Doe',
                    'authorRole': 'Corresponding',
                    'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
                },
                {
                    'givenName': 'Jane',
                    'familyName': 'Smith',
                    'authorRole': 'Creator',
                    'digitalIdentifier': {'identifier': '0000-0001-1111-2222'}
                }
            ],
            'Funding': [
                {'funder': 'NSF', 'grant': 'NSF-12345'},
                {'funder': 'NIH', 'grant': 'NIH-67890'}
            ],
            'License': 'CC BY 4.0',
            'Subjects': [
                {'SpeciesList': {'Name': 'Mus musculus'}},
                {'SpeciesList': {'Name': 'Rattus norvegicus'}}
            ],
            'RelatedPublication': [
                {
                    'DOI': '10.1234/example',
                    'Publication': 'Example Paper',
                    'PMID': '12345678',
                    'PMCID': 'PMC1234567'
                }
            ]
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")  # Ignore DOI placeholder warning
            result = create_cloud_metadata_struct(metadata)

        assert result['name'] == 'My Research Dataset'
        assert result['abstract'] == 'A comprehensive research dataset for testing'
        assert result['branchName'] == 'research-dataset'
        assert len(result['contributors']) == 2
        assert result['contributors'][0]['firstName'] == 'John'
        assert result['contributors'][0]['lastName'] == 'Doe'
        assert result['contributors'][0]['orchid'] == '0000-0001-2345-6789'
        assert 'correspondingAuthors' in result
        assert len(result['correspondingAuthors']) == 1
        assert result['funding']['source'] == 'NIH, NSF'
        assert result['license'] == 'CC BY 4.0'
        assert result['numberOfSubjects'] == 2
        assert 'Mus musculus' in result['species']
        assert 'Rattus norvegicus' in result['species']
        assert len(result['associatedPublications']) == 1
        assert result['associatedPublications'][0]['DOI'] == '10.1234/example'

    def test_create_metadata_minimal(self):
        """Test creating cloud metadata with minimal fields."""
        metadata = {
            'DatasetFullName': 'Minimal Dataset',
            'DatasetShortName': 'minimal',
            'Description': 'A minimal dataset',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'MIT',
            'Subjects': []
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            result = create_cloud_metadata_struct(metadata)

        assert result['name'] == 'Minimal Dataset'
        assert result['branchName'] == 'minimal'
        assert len(result['contributors']) == 1

    def test_create_metadata_description_string(self):
        """Test creating metadata when description is string instead of list."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'A single string description',  # String, not list
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'MIT',
            'Subjects': []
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            result = create_cloud_metadata_struct(metadata)

        assert result['abstract'] == 'A single string description'

    def test_create_metadata_doi_warning(self):
        """Test that DOI placeholder generates a warning."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Test',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'MIT',
            'Subjects': []
        }

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            result = create_cloud_metadata_struct(metadata)

            # Should have issued a warning about placeholder DOI
            assert len(w) >= 1
            assert 'placeholder DOI' in str(w[0].message).lower()

        assert 'doi' in result

    def test_create_metadata_no_corresponding_authors(self):
        """Test creating metadata when no corresponding authors."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Test',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',  # Not 'Corresponding'
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'MIT',
            'Subjects': []
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            result = create_cloud_metadata_struct(metadata)

        assert 'correspondingAuthors' not in result

    def test_create_metadata_species_list(self):
        """Test species list handling with different formats."""
        metadata = {
            'DatasetFullName': 'Species Dataset',
            'DatasetShortName': 'species',
            'Description': 'Test',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'MIT',
            'Subjects': [
                {
                    'SpeciesList': [
                        {'Name': 'Species A'},
                        {'Name': 'Species B'}
                    ]
                },
                {
                    'SpeciesList': {'Name': 'Species C'}  # Single species as dict
                }
            ]
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            result = create_cloud_metadata_struct(metadata)

        assert 'species' in result
        species_str = result['species']
        assert 'Species A' in species_str
        assert 'Species B' in species_str
        assert 'Species C' in species_str

    def test_create_metadata_no_orcid(self):
        """Test creating metadata when author has no ORCID."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Test',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': ''}  # Empty ORCID
            }],
            'Funding': [{'funder': 'NSF'}],
            'License': 'MIT',
            'Subjects': []
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            result = create_cloud_metadata_struct(metadata)

        assert result['contributors'][0]['orchid'] == ''

    def test_create_metadata_invalid_raises_error(self):
        """Test that invalid metadata raises an error."""
        invalid_metadata = {
            'DatasetFullName': 'Test',
            # Missing required fields
        }

        with pytest.raises(ValueError):
            create_cloud_metadata_struct(invalid_metadata)

    def test_create_metadata_funding_deduplication(self):
        """Test that funding sources are deduplicated."""
        metadata = {
            'DatasetFullName': 'Test Dataset',
            'DatasetShortName': 'test',
            'Description': 'Test',
            'Author': [{
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            }],
            'Funding': [
                {'funder': 'NSF', 'grant': 'NSF-123'},
                {'funder': 'NSF', 'grant': 'NSF-456'},  # Duplicate funder
                {'funder': 'NIH', 'grant': 'NIH-789'}
            ],
            'License': 'MIT',
            'Subjects': []
        }

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            result = create_cloud_metadata_struct(metadata)

        # Should have deduplicated funders
        assert result['funding']['source'] == 'NIH, NSF'


@pytest.fixture
def valid_metadata():
    """Fixture providing valid metadata structure."""
    return {
        'DatasetFullName': 'Sample Dataset',
        'DatasetShortName': 'sample',
        'Description': ['A sample dataset for testing'],
        'Author': [{
            'givenName': 'John',
            'familyName': 'Doe',
            'authorRole': 'Corresponding',
            'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
        }],
        'Funding': [{'funder': 'NSF', 'grant': 'NSF-12345'}],
        'License': 'CC BY 4.0',
        'Subjects': []
    }


@pytest.fixture
def complete_metadata():
    """Fixture providing complete metadata with all fields."""
    return {
        'DatasetFullName': 'Complete Research Dataset',
        'DatasetShortName': 'complete-research',
        'Description': ['A fully populated research dataset'],
        'Author': [
            {
                'givenName': 'John',
                'familyName': 'Doe',
                'authorRole': 'Corresponding',
                'digitalIdentifier': {'identifier': '0000-0001-2345-6789'}
            },
            {
                'givenName': 'Jane',
                'familyName': 'Smith',
                'authorRole': 'Creator',
                'digitalIdentifier': {'identifier': '0000-0001-1111-2222'}
            }
        ],
        'Funding': [
            {'funder': 'NSF', 'grant': 'NSF-12345'},
            {'funder': 'NIH', 'grant': 'NIH-67890'}
        ],
        'License': 'CC BY 4.0',
        'Subjects': [
            {'SpeciesList': {'Name': 'Mus musculus'}},
            {'SpeciesList': {'Name': 'Rattus norvegicus'}}
        ],
        'RelatedPublication': [
            {
                'DOI': '10.1234/example',
                'Publication': 'Example Paper',
                'PMID': '12345678',
                'PMCID': 'PMC1234567'
            }
        ]
    }


def test_integration_validate_and_create(valid_metadata):
    """Integration test: validate metadata then create cloud struct."""
    # First validate
    must_be_valid_metadata(valid_metadata)

    # Then create cloud struct
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        cloud_metadata = create_cloud_metadata_struct(valid_metadata)

    assert cloud_metadata['name'] == 'Sample Dataset'
    assert cloud_metadata['branchName'] == 'sample'
    assert len(cloud_metadata['contributors']) == 1


def test_integration_complete_metadata_workflow(complete_metadata):
    """Integration test: full workflow with complete metadata."""
    # Validate
    is_valid = check_metadata_cloud_inputs(complete_metadata)
    assert is_valid is True

    # Create cloud struct
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        cloud_metadata = create_cloud_metadata_struct(complete_metadata)

    # Verify all fields
    assert cloud_metadata['name'] == 'Complete Research Dataset'
    assert len(cloud_metadata['contributors']) == 2
    assert len(cloud_metadata['correspondingAuthors']) == 1
    assert 'NSF' in cloud_metadata['funding']['source']
    assert 'NIH' in cloud_metadata['funding']['source']
    assert cloud_metadata['numberOfSubjects'] == 2
    assert len(cloud_metadata['associatedPublications']) == 1


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
