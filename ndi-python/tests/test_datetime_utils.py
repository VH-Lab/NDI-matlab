"""
Tests for NDI Datetime utilities - datestamp2datetime and datetime2datestamp functions.
"""

import pytest
from datetime import datetime
import pytz
from ndi.util import datestamp2datetime, datetime2datestamp


class TestDatestamp2Datetime:
    """Test the datestamp2datetime function."""

    def test_valid_datestamp(self):
        """Test a valid datestamp string."""
        datestamp_str = '2023-10-26T10:30:00.123+00:00'
        expected_datetime = datetime(2023, 10, 26, 10, 30, 0, 123000, tzinfo=pytz.UTC)

        actual_datetime = datestamp2datetime(datestamp_str)

        assert actual_datetime == expected_datetime, \
            f'Expected {expected_datetime}, got {actual_datetime}'

    def test_beginning_of_year(self):
        """Test a datestamp at the beginning of a year."""
        datestamp_str = '2025-01-01T00:00:00.000+00:00'
        expected_datetime = datetime(2025, 1, 1, 0, 0, 0, 0, tzinfo=pytz.UTC)

        actual_datetime = datestamp2datetime(datestamp_str)

        assert actual_datetime == expected_datetime, \
            f'Expected {expected_datetime}, got {actual_datetime}'

    def test_different_timezone(self):
        """Test a datestamp with a different timezone that should be converted to UTC."""
        datestamp_str = '2023-10-26T15:30:00.123+05:00'  # 5 hours ahead of UTC
        expected_datetime = datetime(2023, 10, 26, 10, 30, 0, 123000, tzinfo=pytz.UTC)

        actual_datetime = datestamp2datetime(datestamp_str)

        assert actual_datetime == expected_datetime, \
            f'Expected {expected_datetime} (UTC), got {actual_datetime}'

    def test_invalid_format_error(self):
        """Test that an invalid format raises an error."""
        invalid_datestamp_str = '2023/10/26 10:30:00'

        with pytest.raises(ValueError) as exc_info:
            datestamp2datetime(invalid_datestamp_str)

        assert 'Cannot parse datestamp string' in str(exc_info.value), \
            'Expected ValueError with parse error message'

    def test_non_string_input(self):
        """Test that a non-string input raises a TypeError."""
        non_string_input = {'field': 'value'}

        with pytest.raises(TypeError) as exc_info:
            datestamp2datetime(non_string_input)

        assert 'must be a string' in str(exc_info.value), \
            'Expected TypeError for non-string input'

    def test_empty_string(self):
        """Test that an empty string raises a ValueError."""
        with pytest.raises(ValueError) as exc_info:
            datestamp2datetime('')

        assert 'cannot be empty' in str(exc_info.value), \
            'Expected ValueError for empty string'

    def test_negative_timezone(self):
        """Test a datestamp with a negative timezone offset."""
        datestamp_str = '2023-10-26T05:30:00.123-05:00'  # 5 hours behind UTC
        expected_datetime = datetime(2023, 10, 26, 10, 30, 0, 123000, tzinfo=pytz.UTC)

        actual_datetime = datestamp2datetime(datestamp_str)

        assert actual_datetime == expected_datetime, \
            f'Expected {expected_datetime} (UTC), got {actual_datetime}'


class TestDatetime2Datestamp:
    """Test the datetime2datestamp function."""

    def test_datetime_to_datestamp(self):
        """Test converting a datetime to datestamp string."""
        dt = datetime(2023, 10, 26, 10, 30, 0, 123000, tzinfo=pytz.UTC)
        expected_datestamp = '2023-10-26T10:30:00.123+00:00'

        actual_datestamp = datetime2datestamp(dt)

        assert actual_datestamp == expected_datestamp, \
            f'Expected {expected_datestamp}, got {actual_datestamp}'

    def test_naive_datetime(self):
        """Test that a naive datetime is assumed to be UTC."""
        dt = datetime(2023, 10, 26, 10, 30, 0, 123000)  # No timezone
        expected_datestamp = '2023-10-26T10:30:00.123+00:00'

        actual_datestamp = datetime2datestamp(dt)

        assert actual_datestamp == expected_datestamp, \
            f'Expected {expected_datestamp}, got {actual_datestamp}'

    def test_timezone_conversion(self):
        """Test that a datetime with a different timezone is converted to UTC."""
        # Create a datetime in EST (UTC-5)
        est = pytz.timezone('US/Eastern')
        dt = est.localize(datetime(2023, 10, 26, 5, 30, 0, 123000))
        # Should be converted to UTC (10:30 instead of 5:30)
        expected_datestamp = '2023-10-26T09:30:00.123+00:00'  # EST is UTC-4 in October (DST)

        actual_datestamp = datetime2datestamp(dt)

        assert actual_datestamp == expected_datestamp, \
            f'Expected {expected_datestamp}, got {actual_datestamp}'

    def test_non_datetime_input(self):
        """Test that a non-datetime input raises a TypeError."""
        non_datetime_input = '2023-10-26'

        with pytest.raises(TypeError) as exc_info:
            datetime2datestamp(non_datetime_input)

        assert 'must be a datetime object' in str(exc_info.value), \
            'Expected TypeError for non-datetime input'

    def test_round_trip(self):
        """Test that converting datestamp->datetime->datestamp is idempotent."""
        original_datestamp = '2023-10-26T10:30:00.123+00:00'

        dt = datestamp2datetime(original_datestamp)
        result_datestamp = datetime2datestamp(dt)

        assert result_datestamp == original_datestamp, \
            f'Round trip failed: {original_datestamp} -> {result_datestamp}'

    def test_microseconds_truncated(self):
        """Test that microseconds are truncated to milliseconds."""
        dt = datetime(2023, 10, 26, 10, 30, 0, 123456, tzinfo=pytz.UTC)
        expected_datestamp = '2023-10-26T10:30:00.123+00:00'  # 456 microseconds truncated

        actual_datestamp = datetime2datestamp(dt)

        assert actual_datestamp == expected_datestamp, \
            f'Expected {expected_datestamp}, got {actual_datestamp}'
