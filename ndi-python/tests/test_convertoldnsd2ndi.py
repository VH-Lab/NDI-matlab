"""
Tests for convertoldnsd2ndi legacy migration utility.

Tests the conversion of old 'nsd' naming to new 'ndi' naming convention.
"""

import pytest
import tempfile
import shutil
from pathlib import Path
from ndi.fun.convertoldnsd2ndi import convertoldnsd2ndi


class TestConvertOldNSD2NDI:
    """Test suite for convertoldnsd2ndi function."""

    def setup_method(self):
        """Create a temporary directory for each test."""
        self.test_dir = Path(tempfile.mkdtemp(prefix='test_nsd_convert_'))

    def teardown_method(self):
        """Clean up temporary directory after each test."""
        if self.test_dir.exists():
            shutil.rmtree(self.test_dir)

    def test_basic_file_rename(self):
        """Test renaming files with 'nsd' in the name."""
        # Create test files
        (self.test_dir / 'nsd_data.txt').write_text('content')
        (self.test_dir / 'NSD_DATA.json').write_text('{"key": "value"}')
        (self.test_dir / 'regular_file.txt').write_text('regular')

        # Convert with dry run first
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=True)
        assert files_renamed == 2  # Two files should be renamed

        # Actually convert
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=False)
        assert files_renamed == 2

        # Check results
        assert (self.test_dir / 'ndi_data.txt').exists()
        assert (self.test_dir / 'NDI_DATA.json').exists()
        assert (self.test_dir / 'regular_file.txt').exists()
        assert not (self.test_dir / 'nsd_data.txt').exists()

    def test_directory_rename(self):
        """Test renaming directories with 'nsd' in the name."""
        # Create test directory structure
        nsd_dir = self.test_dir / 'nsd_sessions'
        nsd_dir.mkdir()
        (nsd_dir / 'file.txt').write_text('content')

        # Convert
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=False)
        assert files_renamed == 1  # One directory renamed

        # Check results
        assert (self.test_dir / 'ndi_sessions').exists()
        assert (self.test_dir / 'ndi_sessions' / 'file.txt').exists()
        assert not (self.test_dir / 'nsd_sessions').exists()

    def test_content_replacement(self):
        """Test replacing 'nsd' and 'NSD' in file contents."""
        # Create test file with nsd content
        test_file = self.test_dir / 'test.txt'
        test_file.write_text('This is nsd data. NSD is old.')

        # Convert
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=False)
        assert files_modified == 1

        # Check content
        content = test_file.read_text()
        assert 'ndi' in content
        assert 'NDI' in content
        assert 'nsd' not in content
        assert 'NSD' not in content

    def test_nested_directories(self):
        """Test conversion in nested directory structure."""
        # Create nested structure
        nsd_dir1 = self.test_dir / 'nsd_level1'
        nsd_dir2 = nsd_dir1 / 'nsd_level2'
        nsd_dir2.mkdir(parents=True)
        (nsd_dir2 / 'nsd_file.json').write_text('{"nsd": true}')

        # Convert
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=False)

        # Check all levels renamed
        assert (self.test_dir / 'ndi_level1' / 'ndi_level2' / 'ndi_file.json').exists()
        assert not nsd_dir1.exists()

    def test_json_file_content(self):
        """Test JSON file content replacement."""
        # Create JSON with nsd references
        json_file = self.test_dir / 'data.json'
        json_file.write_text('{"session_type": "nsd", "NSD_VERSION": "1.0"}')

        # Convert
        convertoldnsd2ndi(str(self.test_dir), dry_run=False)

        # Check content
        content = json_file.read_text()
        assert '"session_type": "ndi"' in content
        assert '"NDI_VERSION": "1.0"' in content

    def test_object_files(self):
        """Test object_* file content replacement."""
        # Create object file
        obj_file = self.test_dir / 'object_123.dat'
        obj_file.write_text('nsd object data NSD')

        # Convert
        convertoldnsd2ndi(str(self.test_dir), dry_run=False)

        # Check content
        content = obj_file.read_text()
        assert 'ndi object data NDI' == content

    def test_dry_run_no_changes(self):
        """Test that dry_run=True makes no actual changes."""
        # Create test file
        test_file = self.test_dir / 'nsd_test.txt'
        test_file.write_text('nsd content')

        # Dry run
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=True)
        assert files_renamed > 0  # Should report changes

        # Verify nothing changed
        assert test_file.exists()
        assert not (self.test_dir / 'ndi_test.txt').exists()
        assert test_file.read_text() == 'nsd content'

    def test_invalid_path(self):
        """Test error handling for invalid path."""
        with pytest.raises(ValueError, match="does not exist"):
            convertoldnsd2ndi('/nonexistent/path', dry_run=False)

    def test_file_instead_of_directory(self):
        """Test error handling when given a file instead of directory."""
        test_file = self.test_dir / 'file.txt'
        test_file.write_text('content')

        with pytest.raises(ValueError, match="not a directory"):
            convertoldnsd2ndi(str(test_file), dry_run=False)

    def test_deprecation_warning(self):
        """Test that deprecation warning is issued."""
        # Create minimal test structure
        (self.test_dir / 'test.txt').write_text('content')

        # Check warning is issued
        with pytest.warns(DeprecationWarning, match="deprecated"):
            convertoldnsd2ndi(str(self.test_dir), dry_run=True)

    def test_mixed_case_preservation(self):
        """Test that case is preserved where appropriate."""
        # Create files with mixed case
        (self.test_dir / 'MyNSD_File.txt').write_text('My NSD data')

        # Convert
        convertoldnsd2ndi(str(self.test_dir), dry_run=False)

        # Check - should rename file but preserve 'My'
        assert (self.test_dir / 'MyNDI_File.txt').exists()
        content = (self.test_dir / 'MyNDI_File.txt').read_text()
        assert content == 'My NDI data'

    def test_no_files_to_convert(self):
        """Test handling when there are no nsd files."""
        # Create files without nsd
        (self.test_dir / 'regular.txt').write_text('regular content')
        (self.test_dir / 'data.json').write_text('{"key": "value"}')

        # Convert
        files_renamed, files_modified = convertoldnsd2ndi(str(self.test_dir), dry_run=False)

        # Should report no changes
        assert files_renamed == 0
        assert files_modified == 0

    def test_encoding_handling(self):
        """Test that different encodings are handled."""
        # Create UTF-8 file
        utf8_file = self.test_dir / 'utf8.txt'
        utf8_file.write_text('nsd données', encoding='utf-8')

        # Convert
        convertoldnsd2ndi(str(self.test_dir), dry_run=False)

        # Should handle without errors
        content = utf8_file.read_text(encoding='utf-8')
        assert 'ndi' in content


class TestConvenienceAlias:
    """Test the convenience alias function."""

    def test_alias_exists(self):
        """Test that convert_old_nsd_to_ndi alias exists."""
        from ndi.fun.convertoldnsd2ndi import convert_old_nsd_to_ndi
        assert convert_old_nsd_to_ndi is convertoldnsd2ndi


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
