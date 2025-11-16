"""
Tests for Phase 3 utilities.

Tests for ndi.fun, ndi.util, and ndi.common utilities added in Phase 3.
"""

import pytest
import os
import tempfile


class TestNdiFunUtilities:
    """Test ndi.fun utilities."""

    def test_timestamp(self):
        """Test timestamp generation."""
        from ndi.fun import timestamp
        ts = timestamp()
        assert isinstance(ts, str)
        assert len(ts) > 0
        # Should not contain 60.000 seconds
        assert '60.000' not in ts

    def test_channelname2prefixnumber(self):
        """Test channel name parsing."""
        from ndi.fun import channelname2prefixnumber, prefixnumber2channelname

        prefix, num = channelname2prefixnumber('ch42')
        assert prefix == 'ch'
        assert num == 42

        name = prefixnumber2channelname('ch', 42)
        assert name == 'ch42'

    def test_pseudorandomint(self):
        """Test pseudo-random integer generation."""
        from ndi.fun import pseudorandomint

        num = pseudorandomint(1, 100)
        assert 1 <= num <= 100

        # Test reproducibility with seed
        num1 = pseudorandomint(1, 100, seed=42)
        num2 = pseudorandomint(1, 100, seed=42)
        assert num1 == num2

    def test_check_toolboxes(self):
        """Test toolbox checking."""
        from ndi.fun import check_toolboxes

        status = check_toolboxes(['os', 'sys'])  # Built-in modules
        assert status['os'] is True
        assert status['sys'] is True

        status = check_toolboxes(['nonexistent_package_xyz'])
        assert status['nonexistent_package_xyz'] is False

    def test_find_calc_directories(self):
        """Test finding calculator directories."""
        from ndi.fun import find_calc_directories

        dirs = find_calc_directories()
        assert isinstance(dirs, list)


class TestNdiUtilUtilities:
    """Test ndi.util utilities."""

    def test_string_utils(self):
        """Test string manipulation utilities."""
        from ndi.util import sanitize_filename, camel_to_snake, snake_to_camel

        safe = sanitize_filename('file<>name?.txt')
        assert '<' not in safe
        assert '>' not in safe
        assert '?' not in safe

        assert camel_to_snake('MyClassName') == 'my_class_name'
        assert snake_to_camel('my_variable_name') == 'MyVariableName'

    def test_math_utils(self):
        """Test mathematical utilities."""
        from ndi.util import safe_divide, clamp

        assert safe_divide(10, 2) == 5
        assert safe_divide(10, 0, default=0) == 0

        assert clamp(5, 0, 10) == 5
        assert clamp(-1, 0, 10) == 0
        assert clamp(15, 0, 10) == 10

    def test_file_utils(self):
        """Test file utilities."""
        from ndi.util import ensure_dir, file_md5, get_file_size

        with tempfile.TemporaryDirectory() as tmpdir:
            test_dir = os.path.join(tmpdir, 'test_subdir')
            ensure_dir(test_dir)
            assert os.path.exists(test_dir)

            # Test file MD5
            test_file = os.path.join(tmpdir, 'test.txt')
            with open(test_file, 'w') as f:
                f.write('test content')

            md5 = file_md5(test_file)
            assert md5 is not None
            assert len(md5) == 32  # MD5 is 32 hex characters

            size = get_file_size(test_file)
            assert size > 0

    def test_cache_utils(self):
        """Test cache utilities."""
        from ndi.util import SimpleCache

        with tempfile.TemporaryDirectory() as tmpdir:
            cache = SimpleCache(cache_dir=tmpdir, ttl=60)

            # Test set and get
            cache.set('test_key', 'test_value')
            assert cache.get('test_key') == 'test_value'

            # Test non-existent key
            assert cache.get('nonexistent', default='default') == 'default'

            # Test clear
            cache.clear()
            assert cache.get('test_key', default=None) is None


class TestNdiCommonUtilities:
    """Test ndi.common utilities."""

    def test_logger(self):
        """Test logger functionality."""
        from ndi.common import Logger, get_logger

        logger = get_logger()
        assert isinstance(logger, Logger)
        assert hasattr(logger, 'system_logfile')
        assert hasattr(logger, 'debug_logfile')
        assert hasattr(logger, 'error_logfile')

        # Test logging methods
        logger.log_system('test system message')
        logger.log_debug('test debug message')
        logger.log_error('test error message')

    def test_path_constants(self):
        """Test path constants."""
        from ndi.common import PathConstants

        ndi_root = PathConstants.get_ndi_root()
        assert os.path.exists(ndi_root)

        user_folder = PathConstants.get_user_folder()
        assert '.' in user_folder or 'ndi' in user_folder.lower()

    def test_did_integration(self):
        """Test DID integration utilities."""
        from ndi.common import check_did_available

        # Just test that the function exists and returns a boolean
        available = check_did_available()
        assert isinstance(available, bool)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
