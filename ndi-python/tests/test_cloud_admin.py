"""
Comprehensive tests for cloud admin (DOI) module.

Tests DOI generation, dataset to Crossref conversion, metadata conversion,
license mapping, contributor/ORCID handling, and date conversion.
"""

import pytest
from datetime import datetime
from unittest.mock import Mock, patch

from ndi.cloud.admin.create_new_doi import create_new_doi, generate_random_doi_suffix
from ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref import (
    convert_cloud_dataset_to_crossref_dataset,
    convert_cloud_dataset_to_crossref_dataset_object,
    Dataset
)
from ndi.cloud.admin.crossref.conversion.convert_license import (
    convert_license,
    convert_license_object,
    _get_license_url,
    add_license_mapping
)
from ndi.cloud.admin.crossref.conversion.convert_contributors import (
    convert_contributors,
    convert_contributors_object,
    ORCID,
    PersonName,
    Contributors
)
from ndi.cloud.admin.crossref.conversion.convert_dataset_date import (
    convert_dataset_date,
    convert_dataset_date_object,
    timestamp_to_year_month_day,
    PublicationDate,
    DatabaseDate
)


class TestCreateNewDOI:
    """Tests for DOI generation functions."""

    def test_create_new_doi_format(self):
        """Test DOI format is correct."""
        doi = create_new_doi()

        # Should have format: 10.63884/ndic.YYYY.xxxxxxxx
        assert doi.startswith('10.63884/ndic.')
        parts = doi.split('.')
        assert len(parts) == 4
        assert parts[0] == '10'
        assert parts[1] == '63884/ndic'
        # Year should be current year
        assert parts[2] == str(datetime.now().year)
        # Random suffix should be 8 characters
        assert len(parts[3]) == 8

    def test_doi_uniqueness(self):
        """Test that generated DOIs are unique."""
        doi1 = create_new_doi()
        doi2 = create_new_doi()

        assert doi1 != doi2

    def test_generate_random_doi_suffix_length(self):
        """Test random suffix generation with custom length."""
        suffix = generate_random_doi_suffix(12)

        assert len(suffix) == 12
        assert suffix.islower() or suffix.isdigit()  # lowercase letters or digits

    def test_generate_random_doi_suffix_default_length(self):
        """Test random suffix generation with default length."""
        suffix = generate_random_doi_suffix()

        assert len(suffix) == 8

    def test_generate_random_doi_suffix_characters(self):
        """Test that suffix only contains valid characters."""
        import string
        valid_chars = set(string.ascii_lowercase + string.digits)

        for _ in range(10):
            suffix = generate_random_doi_suffix()
            assert all(c in valid_chars for c in suffix)


class TestConvertLicense:
    """Tests for license conversion functions."""

    def test_convert_license_cc_by(self):
        """Test converting CC-BY-4.0 license."""
        dataset = {'license': 'CC-BY-4.0'}
        result = convert_license(dataset)

        assert result is not None
        assert 'license_ref' in result
        assert result['license_ref']['value'] == 'https://creativecommons.org/licenses/by/4.0/'

    def test_convert_license_multiple_formats(self):
        """Test converting various license formats."""
        test_cases = [
            ('CC-BY-NC-4.0', 'https://creativecommons.org/licenses/by-nc/4.0/'),
            ('MIT', 'https://opensource.org/licenses/MIT'),
            ('Apache-2.0', 'https://www.apache.org/licenses/LICENSE-2.0'),
        ]

        for license_name, expected_url in test_cases:
            dataset = {'license': license_name}
            result = convert_license(dataset)
            assert result['license_ref']['value'] == expected_url

    def test_convert_license_no_license(self):
        """Test converting dataset with no license."""
        dataset = {}
        result = convert_license(dataset)

        assert result is None

    def test_convert_license_empty_license(self):
        """Test converting dataset with empty license."""
        dataset = {'license': ''}
        result = convert_license(dataset)

        assert result is None

    def test_convert_license_url_passthrough(self):
        """Test that URLs are passed through directly."""
        custom_url = 'https://custom-license.org/my-license'
        dataset = {'license': custom_url}
        result = convert_license(dataset)

        assert result['license_ref']['value'] == custom_url

    def test_convert_license_unknown(self):
        """Test converting unknown license creates placeholder."""
        dataset = {'license': 'UnknownLicense-1.0'}

        with patch('builtins.print'):  # Suppress warning
            result = convert_license(dataset)

        assert 'license_ref' in result
        assert 'UnknownLicense-1.0' in result['license_ref']['value']

    def test_get_license_url_case_insensitive(self):
        """Test license URL lookup is case-insensitive."""
        url1 = _get_license_url('cc-by-4.0')
        url2 = _get_license_url('CC-BY-4.0')

        assert url1 == url2

    def test_add_license_mapping(self):
        """Test adding custom license mapping."""
        add_license_mapping('Custom-License', 'https://example.com/license')

        dataset = {'license': 'Custom-License'}
        result = convert_license(dataset)

        assert result['license_ref']['value'] == 'https://example.com/license'

    def test_convert_license_object(self):
        """Test converting license to AiProgram object."""
        dataset = {'license': 'MIT'}
        ai_program = convert_license_object(dataset)

        assert ai_program is not None
        assert ai_program.license_ref.value == 'https://opensource.org/licenses/MIT'
        assert isinstance(ai_program.to_dict(), dict)


class TestConvertContributors:
    """Tests for contributor conversion functions."""

    def test_convert_single_contributor(self):
        """Test converting a single contributor."""
        dataset = {
            'contributors': [{
                'firstName': 'John',
                'lastName': 'Doe',
                'orcid': '0000-0001-2345-6789'
            }]
        }

        result = convert_contributors(dataset)

        assert 'items' in result
        assert len(result['items']) == 1
        assert result['items'][0]['given_name'] == 'John'
        assert result['items'][0]['surname'] == 'Doe'
        assert result['items'][0]['sequence'] == 'first'
        assert result['items'][0]['contributor_role'] == 'author'
        assert result['items'][0]['orcid']['value'] == 'https://orcid.org/0000-0001-2345-6789'

    def test_convert_multiple_contributors(self):
        """Test converting multiple contributors."""
        dataset = {
            'contributors': [
                {'firstName': 'John', 'lastName': 'Doe'},
                {'firstName': 'Jane', 'lastName': 'Smith'},
                {'firstName': 'Bob', 'lastName': 'Johnson'}
            ]
        }

        result = convert_contributors(dataset)

        assert len(result['items']) == 3
        assert result['items'][0]['sequence'] == 'first'
        assert result['items'][1]['sequence'] == 'additional'
        assert result['items'][2]['sequence'] == 'additional'

    def test_convert_contributor_with_orcid_url(self):
        """Test converting contributor with full ORCID URL."""
        dataset = {
            'contributors': [{
                'firstName': 'John',
                'lastName': 'Doe',
                'orcid': 'https://orcid.org/0000-0001-2345-6789'
            }]
        }

        result = convert_contributors(dataset)

        assert result['items'][0]['orcid']['value'] == 'https://orcid.org/0000-0001-2345-6789'

    def test_convert_contributor_without_orcid(self):
        """Test converting contributor without ORCID."""
        dataset = {
            'contributors': [{
                'firstName': 'John',
                'lastName': 'Doe'
            }]
        }

        result = convert_contributors(dataset)

        assert result['items'][0]['orcid'] is None

    def test_convert_contributor_missing_names(self):
        """Test converting contributor with missing names."""
        dataset = {
            'contributors': [{'orcid': '0000-0001-2345-6789'}]
        }

        result = convert_contributors(dataset)

        assert result['items'][0]['given_name'] is None
        assert result['items'][0]['surname'] is None

    def test_orcid_validation(self):
        """Test ORCID validation."""
        assert ORCID.validate('0000-0001-2345-6789') is True
        assert ORCID.validate('https://orcid.org/0000-0001-2345-6789') is True
        assert ORCID.validate('invalid-orcid') is False
        assert ORCID.validate('0000-0001-2345') is False

    def test_orcid_object_creation(self):
        """Test creating ORCID object."""
        # With numeric ORCID
        orcid1 = ORCID('0000-0001-2345-6789')
        assert orcid1.value == 'https://orcid.org/0000-0001-2345-6789'

        # With full URL
        orcid2 = ORCID('https://orcid.org/0000-0001-2345-6789')
        assert orcid2.value == 'https://orcid.org/0000-0001-2345-6789'

    def test_convert_contributors_object(self):
        """Test converting contributors to Contributors object."""
        dataset = {
            'contributors': [
                {'firstName': 'John', 'lastName': 'Doe', 'orcid': '0000-0001-2345-6789'}
            ]
        }

        contributors = convert_contributors_object(dataset)

        assert isinstance(contributors, Contributors)
        assert len(contributors.items) == 1
        assert isinstance(contributors.items[0], PersonName)
        assert contributors.items[0].given_name == 'John'


class TestConvertDatasetDate:
    """Tests for dataset date conversion functions."""

    def test_convert_dataset_date(self):
        """Test converting dataset dates."""
        dataset = {
            'createdAt': '2025-01-15T10:30:00.000Z',
            'updatedAt': '2025-01-16T14:45:00.000Z'
        }

        result = convert_dataset_date(dataset)

        assert 'publication_date' in result
        assert 'creation_date' in result
        assert 'update_date' in result

        assert result['creation_date']['year'] == '2025'
        assert result['creation_date']['month'] == '01'
        assert result['creation_date']['day'] == '15'
        assert result['creation_date']['media_type'] == 'online'

        assert result['update_date']['year'] == '2025'
        assert result['update_date']['month'] == '01'
        assert result['update_date']['day'] == '16'

    def test_convert_dataset_date_invalid_timestamp(self):
        """Test handling invalid timestamps."""
        dataset = {
            'createdAt': 'invalid-timestamp',
            'updatedAt': 'also-invalid'
        }

        # Should fallback to current date
        result = convert_dataset_date(dataset)

        now = datetime.now()
        assert result['creation_date']['year'] == str(now.year)
        assert result['creation_date']['month'] == f'{now.month:02d}'

    def test_timestamp_to_year_month_day(self):
        """Test timestamp parsing."""
        timestamp = '2025-01-15T10:30:00.000Z'
        year, month, day = timestamp_to_year_month_day(timestamp)

        assert year == 2025
        assert month == 1
        assert day == 15

    def test_timestamp_to_year_month_day_invalid(self):
        """Test timestamp parsing with invalid input."""
        year, month, day = timestamp_to_year_month_day('invalid')

        # Should return current date
        now = datetime.now()
        assert year == now.year
        assert month == now.month
        assert day == now.day

    def test_publication_date_from_datetime(self):
        """Test creating PublicationDate from datetime."""
        dt = datetime(2025, 1, 15, 10, 30, 0)
        pub_date = PublicationDate.from_datetime(dt)

        assert pub_date.year == '2025'
        assert pub_date.month == '01'
        assert pub_date.day == '15'
        assert pub_date.media_type == 'online'

    def test_database_date_object(self):
        """Test DatabaseDate object creation."""
        pub_date = PublicationDate('2025', '01', '15', 'online')

        from ndi.cloud.admin.crossref.conversion.convert_dataset_date import CreationDate, UpdateDate
        create_date = CreationDate('2025', '01', '15', 'online')
        update_date = UpdateDate('2025', '01', '16', 'online')

        db_date = DatabaseDate(pub_date, create_date, update_date)

        db_dict = db_date.to_dict()
        assert 'publication_date' in db_dict
        assert 'creation_date' in db_dict
        assert 'update_date' in db_dict

    def test_convert_dataset_date_object(self):
        """Test converting to DatabaseDate object."""
        dataset = {
            'createdAt': '2025-01-15T10:00:00.000Z',
            'updatedAt': '2025-01-16T10:00:00.000Z'
        }

        db_date = convert_dataset_date_object(dataset)

        assert isinstance(db_date, DatabaseDate)
        assert db_date.creation_date.year == '2025'


class TestConvertCloudDatasetToCrossref:
    """Tests for cloud dataset to Crossref conversion."""

    def test_convert_complete_dataset(self):
        """Test converting complete dataset."""
        cloud_dataset = {
            'name': 'Test Dataset',
            'abstract': 'A test dataset description',
            'contributors': [
                {'firstName': 'John', 'lastName': 'Doe', 'orcid': '0000-0001-2345-6789'}
            ],
            'createdAt': '2025-01-15T10:00:00.000Z',
            'updatedAt': '2025-01-15T11:00:00.000Z',
            'license': 'CC-BY-4.0',
            'funding': [{'source': 'NSF', 'grant': 'ABC123'}],
            'x_id': 'dataset_abc123'
        }

        with patch('ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref.Constants.get_dataset_url') as mock_url:
            mock_url.return_value = 'https://ndicloud.org/datasets/dataset_abc123'

            result = convert_cloud_dataset_to_crossref_dataset(cloud_dataset)

            assert result is not None
            assert result['titles']['title'] == 'Test Dataset'
            assert result['description'] == 'A test dataset description'
            assert 'contributors' in result
            assert 'doi_data' in result
            assert result['doi_data']['doi'].startswith('10.63884/ndic.')
            assert result['doi_data']['resource'] == 'https://ndicloud.org/datasets/dataset_abc123'
            assert result['dataset_type'] == 'record'

    def test_convert_empty_dataset(self):
        """Test converting empty dataset."""
        result = convert_cloud_dataset_to_crossref_dataset({})

        assert result is None

    def test_convert_dataset_with_existing_doi(self):
        """Test error when dataset already has DOI."""
        cloud_dataset = {
            'name': 'Test Dataset',
            'doi': '10.12345/existing-doi',
            'x_id': 'test123'
        }

        with pytest.raises(ValueError, match="already has DOI"):
            convert_cloud_dataset_to_crossref_dataset(cloud_dataset)

    def test_convert_dataset_minimal_fields(self):
        """Test converting dataset with minimal required fields."""
        cloud_dataset = {
            'name': 'Minimal Dataset',
            'x_id': 'minimal123'
        }

        with patch('ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref.Constants.get_dataset_url') as mock_url:
            mock_url.return_value = 'https://ndicloud.org/datasets/minimal123'

            result = convert_cloud_dataset_to_crossref_dataset(cloud_dataset)

            assert result is not None
            assert result['titles']['title'] == 'Minimal Dataset'
            assert result['description'] == ''

    def test_convert_dataset_to_object(self):
        """Test converting to Dataset object."""
        cloud_dataset = {
            'name': 'Test Dataset',
            'x_id': 'test123',
            'contributors': [],
            'createdAt': '2025-01-15T10:00:00.000Z',
            'updatedAt': '2025-01-15T11:00:00.000Z'
        }

        with patch('ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref.Constants.get_dataset_url') as mock_url:
            mock_url.return_value = 'https://ndicloud.org/datasets/test123'

            dataset_obj = convert_cloud_dataset_to_crossref_dataset_object(cloud_dataset)

            assert isinstance(dataset_obj, Dataset)
            assert dataset_obj.titles['title'] == 'Test Dataset'
            assert dataset_obj.dataset_type == 'record'

    def test_dataset_object_to_dict(self):
        """Test Dataset object to_dict method."""
        from ndi.cloud.admin.crossref.conversion.convert_dataset_date import DatabaseDate, PublicationDate, CreationDate, UpdateDate

        pub_date = PublicationDate('2025', '01', '15', 'online')
        create_date = CreationDate('2025', '01', '15', 'online')
        update_date = UpdateDate('2025', '01', '15', 'online')
        db_date = DatabaseDate(pub_date, create_date, update_date)

        dataset = Dataset(
            contributors={'items': []},
            titles={'title': 'Test'},
            description='Description',
            doi_data={'doi': '10.12345/test', 'resource': 'https://example.com'},
            dataset_type='record',
            database_date=db_date.to_dict()
        )

        dataset_dict = dataset.to_dict()

        assert 'titles' in dataset_dict
        assert 'doi_data' in dataset_dict
        assert dataset_dict['dataset_type'] == 'record'


@pytest.fixture
def sample_cloud_dataset():
    """Fixture providing a sample cloud dataset."""
    return {
        'name': 'Sample Dataset',
        'abstract': 'A sample dataset for testing',
        'contributors': [
            {'firstName': 'John', 'lastName': 'Doe', 'orcid': '0000-0001-2345-6789'},
            {'firstName': 'Jane', 'lastName': 'Smith'}
        ],
        'createdAt': '2025-01-15T10:00:00.000Z',
        'updatedAt': '2025-01-16T12:00:00.000Z',
        'license': 'CC-BY-4.0',
        'funding': [{'source': 'NSF'}],
        'x_id': 'sample123'
    }


def test_integration_full_conversion(sample_cloud_dataset):
    """Integration test: convert full dataset to Crossref format."""
    with patch('ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref.Constants.get_dataset_url') as mock_url:
        mock_url.return_value = 'https://ndicloud.org/datasets/sample123'

        result = convert_cloud_dataset_to_crossref_dataset(sample_cloud_dataset)

        # Verify all components are present and correctly formatted
        assert result is not None
        assert result['titles']['title'] == 'Sample Dataset'
        assert result['description'] == 'A sample dataset for testing'

        # Check contributors
        assert len(result['contributors']['items']) == 2
        assert result['contributors']['items'][0]['sequence'] == 'first'
        assert result['contributors']['items'][1]['sequence'] == 'additional'

        # Check DOI
        assert result['doi_data']['doi'].startswith('10.63884/ndic.2025.')
        assert result['doi_data']['resource'] == 'https://ndicloud.org/datasets/sample123'

        # Check dates
        assert result['database_date']['creation_date']['year'] == '2025'
        assert result['database_date']['creation_date']['month'] == '01'
        assert result['database_date']['creation_date']['day'] == '15'

        # Check license
        assert result['ai_program']['license_ref']['value'] == 'https://creativecommons.org/licenses/by/4.0/'


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
