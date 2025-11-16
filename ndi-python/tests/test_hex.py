"""
Tests for NDI Hex utilities - hex_diff, hex_dump, and get_hex_diff_from_file_obj.
"""

import pytest
import tempfile
import os
from pathlib import Path
from ndi.util import hex_diff, hex_dump, get_hex_diff_from_file_obj


class TestHexDiff:
    """Test the hex_diff function."""

    @pytest.fixture
    def test_dir(self, tmp_path):
        """Create a temporary directory for test files."""
        return tmp_path

    @pytest.fixture
    def base_content(self):
        """Create base test content (3 lines worth)."""
        return bytes(range(48))  # 0-47

    def write_file(self, filename, content):
        """Helper to write binary content to a file."""
        with open(filename, 'wb') as f:
            f.write(content)

    def test_identical_files(self, test_dir, base_content):
        """Test that identical files produce no diff output."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        self.write_file(file1, base_content)
        self.write_file(file2, base_content)

        output = hex_diff(str(file1), str(file2))

        assert 'Files are identical' in output or 'No differences found' in output, \
            'Expected message indicating files are identical'

    def test_single_byte_difference(self, test_dir, base_content):
        """Test a single byte difference."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        # Modify one byte (index 4, which is byte 0x04)
        modified_content = bytearray(base_content)
        modified_content[4] = 255
        modified_content = bytes(modified_content)

        self.write_file(file1, base_content)
        self.write_file(file2, modified_content)

        output = hex_diff(str(file1), str(file2))

        # Verify the first line is printed (contains the difference)
        assert '0x00000000' in output or 'Offset: 0x00000000' in output, 'Expected first line header'
        assert 'ff' in output or 'FF' in output or '0xff' in output or '0xFF' in output, \
            'Expected to see the changed byte (0xFF) in output'

        # Verify the second line offset is NOT printed (no differences there)
        assert '0x00000010' not in output or output.count('0x00000010') == 0, \
            'Second line should not appear when there are no differences'

    def test_shorter_second_file(self, test_dir, base_content):
        """Test when the second file is shorter."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        # File2 has only first 32 bytes (2 lines of 16 bytes)
        shorter_content = base_content[:32]

        self.write_file(file1, base_content)
        self.write_file(file2, shorter_content)

        output = hex_diff(str(file1), str(file2))

        # Verify the third line is printed (bytes 32-47)
        assert '0x00000020' in output or 'Offset: 0x00000020' in output, \
            'Expected third line to show length difference'

    def test_shorter_first_file(self, test_dir, base_content):
        """Test when the first file is shorter."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        # File1 has only first 32 bytes
        shorter_content = base_content[:32]

        self.write_file(file1, shorter_content)
        self.write_file(file2, base_content)

        output = hex_diff(str(file1), str(file2))

        # Verify the third line is printed
        assert '0x00000020' in output or 'Offset: 0x00000020' in output, \
            'Expected third line to show length difference'

    def test_range_options(self, test_dir, base_content):
        """Test using the start_byte and stop_byte options."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        # Modify byte 19 (on the second line)
        modified_content = bytearray(base_content)
        modified_content[19] = 99
        modified_content = bytes(modified_content)

        self.write_file(file1, base_content)
        self.write_file(file2, modified_content)

        # Run diff only on first line (bytes 0-15)
        output = hex_diff(str(file1), str(file2), stop_byte=15)

        # Verify no differences are reported
        assert 'Files are identical' in output or 'No differences found' in output, \
            'Expected no differences in first 16 bytes'

        # Now run on second line (bytes 16-31)
        output = hex_diff(str(file1), str(file2), start_byte=16, stop_byte=31)

        # Verify the difference is found
        assert '0x00000010' in output or 'Offset: 0x00000010' in output, \
            'Expected to find difference in second line'
        assert '63' in output or '0x63' in output, \
            'Expected to see hex value for byte 99 (0x63)'

    def test_file_does_not_exist_error(self, test_dir, base_content):
        """Test error for a non-existent file."""
        file1 = test_dir / 'file1.bin'
        non_existent = test_dir / 'no_such_file.bin'

        self.write_file(file1, base_content)

        with pytest.raises(FileNotFoundError):
            hex_diff(str(file1), str(non_existent))

    def test_invalid_range(self, test_dir, base_content):
        """Test error for invalid byte range."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        self.write_file(file1, base_content)
        self.write_file(file2, base_content)

        # stop_byte < start_byte should raise ValueError
        with pytest.raises(ValueError):
            hex_diff(str(file1), str(file2), start_byte=100, stop_byte=50)


class TestHexDump:
    """Test the hex_dump function."""

    @pytest.fixture
    def test_dir(self, tmp_path):
        """Create a temporary directory for test files."""
        return tmp_path

    def write_file(self, filename, content):
        """Helper to write binary content to a file."""
        with open(filename, 'wb') as f:
            f.write(content)

    def test_simple_hex_dump(self, test_dir):
        """Test basic hex dump functionality."""
        test_file = test_dir / 'test.bin'
        content = bytes(range(32))  # 2 lines of 16 bytes

        self.write_file(test_file, content)

        output = hex_dump(str(test_file))

        # Verify we have two lines of hex dump
        assert '0x00000000' in output, 'Expected first line'
        assert '0x00000010' in output, 'Expected second line'

    def test_hex_dump_with_range(self, test_dir):
        """Test hex dump with start and stop bytes."""
        test_file = test_dir / 'test.bin'
        content = bytes(range(48))  # 3 lines

        self.write_file(test_file, content)

        # Dump only second line (bytes 16-31)
        output = hex_dump(str(test_file), start_byte=16, stop_byte=31)

        # Should only show second line
        assert '0x00000010' in output, 'Expected second line'
        # The output should not contain the first line's offset
        # (except in the header/range info which we'll allow)
        lines = output.split('\n')
        hex_lines = [l for l in lines if l.strip().startswith('0x')]
        assert len(hex_lines) == 1, 'Should only have one hex dump line'
        assert hex_lines[0].startswith('0x00000010'), 'Should be the second line'

    def test_hex_dump_file_not_found(self, test_dir):
        """Test error for non-existent file."""
        non_existent = test_dir / 'no_such_file.bin'

        with pytest.raises(FileNotFoundError):
            hex_dump(str(non_existent))


class TestGetHexDiffFromFileObj:
    """Test the get_hex_diff_from_file_obj function."""

    @pytest.fixture
    def test_dir(self, tmp_path):
        """Create a temporary directory for test files."""
        return tmp_path

    def write_file(self, filename, content):
        """Helper to write binary content to a file."""
        with open(filename, 'wb') as f:
            f.write(content)

    def test_identical_file_objects(self, test_dir):
        """Test that identical file objects produce no diff."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        content = bytes(range(32))
        self.write_file(file1, content)
        self.write_file(file2, content)

        with open(file1, 'rb') as f1, open(file2, 'rb') as f2:
            files_identical, differences = get_hex_diff_from_file_obj(f1, f2)

        # Files should be identical
        assert files_identical is True, 'Expected files to be identical'
        assert len(differences) == 0, 'Expected no differences for identical files'

    def test_different_file_objects(self, test_dir):
        """Test differing file objects."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        content1 = bytes(range(32))
        content2 = bytearray(range(32))
        content2[10] = 255
        content2 = bytes(content2)

        self.write_file(file1, content1)
        self.write_file(file2, content2)

        with open(file1, 'rb') as f1, open(file2, 'rb') as f2:
            files_identical, differences = get_hex_diff_from_file_obj(f1, f2)

        # Files should NOT be identical
        assert files_identical is False, 'Expected files to be different'
        assert len(differences) > 0, 'Expected diff output for different files'

    def test_with_byte_range(self, test_dir):
        """Test with specific byte range."""
        file1 = test_dir / 'file1.bin'
        file2 = test_dir / 'file2.bin'

        content1 = bytes(range(48))
        content2 = bytearray(range(48))
        content2[35] = 255  # Modify byte on third line
        content2 = bytes(content2)

        self.write_file(file1, content1)
        self.write_file(file2, content2)

        # Only check first two lines (bytes 0-31)
        with open(file1, 'rb') as f1, open(file2, 'rb') as f2:
            files_identical, differences = get_hex_diff_from_file_obj(f1, f2, start_byte=0, stop_byte=31)

        # Should show no differences in this range (difference is at byte 35)
        assert files_identical is True, 'Expected files to be identical in bytes 0-31'
        assert len(differences) == 0, 'Expected no differences in bytes 0-31'
