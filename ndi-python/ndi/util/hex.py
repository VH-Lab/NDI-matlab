"""
NDI Hex Utilities - Functions for hex-level file operations.

This module provides utilities for working with files at the hex/byte level,
including hex dumps and hex-level file comparisons.
"""

import os
from typing import Optional, Tuple, List, BinaryIO


def hex_diff(filename1: str, filename2: str,
             start_byte: int = 0,
             stop_byte: Optional[int] = None) -> str:
    """
    Compare two files at the byte level and show hex diff.

    Creates a side-by-side hex view of differing chunks between two files.
    Shows 16-byte chunks with hex values and ASCII representation.

    This is the Python equivalent of MATLAB's ndi.util.hexDiff function.

    Args:
        filename1: Path to first file
        filename2: Path to second file
        start_byte: Starting byte position (0-indexed), defaults to 0
        stop_byte: Stopping byte position (0-indexed), defaults to end of file

    Returns:
        String containing formatted hex diff output

    Raises:
        FileNotFoundError: If either file doesn't exist
        ValueError: If start_byte or stop_byte are invalid

    Examples:
        >>> diff_output = hex_diff('file1.bin', 'file2.bin')
        >>> print(diff_output)
        >>> # Shows side-by-side hex comparison

        >>> diff_output = hex_diff('file1.bin', 'file2.bin', start_byte=100, stop_byte=200)
        >>> # Compare only bytes 100-200

    Notes:
        - Displays 16 bytes per line
        - Shows hex values and ASCII representation
        - Only shows chunks where files differ
        - If files are identical, returns message indicating no differences
    """
    # Validate files exist
    if not os.path.exists(filename1):
        raise FileNotFoundError(f'File not found: {filename1}')
    if not os.path.exists(filename2):
        raise FileNotFoundError(f'File not found: {filename2}')

    # Open both files
    with open(filename1, 'rb') as f1, open(filename2, 'rb') as f2:
        # Get file sizes
        f1.seek(0, 2)  # Seek to end
        size1 = f1.tell()
        f2.seek(0, 2)
        size2 = f2.tell()

        # Validate start_byte
        if start_byte < 0:
            raise ValueError('start_byte must be >= 0')

        # Determine stop_byte
        if stop_byte is None:
            stop_byte = max(size1, size2) - 1
        else:
            if stop_byte < start_byte:
                raise ValueError('stop_byte must be >= start_byte')

        # Seek to start position
        f1.seek(start_byte)
        f2.seek(start_byte)

        # Build output
        output_lines = []
        output_lines.append(f'Hex Diff: {filename1} vs {filename2}')
        output_lines.append(f'Byte Range: {start_byte} to {stop_byte}')
        output_lines.append('')

        # Read and compare in 16-byte chunks
        chunk_size = 16
        current_byte = start_byte
        found_differences = False

        while current_byte <= stop_byte:
            # Calculate how many bytes to read in this chunk
            bytes_to_read = min(chunk_size, stop_byte - current_byte + 1)

            # Read chunks from both files
            chunk1 = f1.read(bytes_to_read)
            chunk2 = f2.read(bytes_to_read)

            # Pad shorter chunk with None (to show missing bytes)
            if len(chunk1) < bytes_to_read:
                chunk1 += b'\x00' * (bytes_to_read - len(chunk1))
            if len(chunk2) < bytes_to_read:
                chunk2 += b'\x00' * (bytes_to_read - len(chunk2))

            # Check if chunks differ
            if chunk1 != chunk2:
                found_differences = True

                # Format chunk output
                output_lines.append(f'Offset: 0x{current_byte:08x} ({current_byte})')
                output_lines.append('')

                # File 1 hex
                hex1 = ' '.join(f'{b:02x}' for b in chunk1)
                output_lines.append(f'  File 1: {hex1}')

                # File 1 ASCII
                ascii1 = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk1)
                output_lines.append(f'          {ascii1}')

                # File 2 hex
                hex2 = ' '.join(f'{b:02x}' for b in chunk2)
                output_lines.append(f'  File 2: {hex2}')

                # File 2 ASCII
                ascii2 = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk2)
                output_lines.append(f'          {ascii2}')

                # Show differences
                diff_line = '          '
                for i in range(len(chunk1)):
                    if i < len(chunk2) and chunk1[i] == chunk2[i]:
                        diff_line += '   '
                    else:
                        diff_line += ' ^^'
                output_lines.append(diff_line)
                output_lines.append('')

            current_byte += bytes_to_read

        if not found_differences:
            output_lines.append('Files are identical in the specified byte range.')

    return '\n'.join(output_lines)


def hex_dump(filename: str,
             start_byte: int = 0,
             stop_byte: Optional[int] = None,
             bytes_per_line: int = 16) -> str:
    """
    Create a hex dump of a file.

    Shows hex values and ASCII representation of file contents.

    Args:
        filename: Path to file
        start_byte: Starting byte position (0-indexed), defaults to 0
        stop_byte: Stopping byte position (0-indexed), defaults to end of file
        bytes_per_line: Number of bytes to display per line, defaults to 16

    Returns:
        String containing formatted hex dump

    Raises:
        FileNotFoundError: If file doesn't exist
        ValueError: If start_byte or stop_byte are invalid

    Examples:
        >>> dump = hex_dump('file.bin')
        >>> print(dump)
        >>> # Shows hex dump of entire file

        >>> dump = hex_dump('file.bin', start_byte=0, stop_byte=255, bytes_per_line=8)
        >>> # Shows first 256 bytes with 8 bytes per line

    Notes:
        - Default format: offset, hex bytes, ASCII representation
        - Non-printable characters shown as '.'
    """
    # Validate file exists
    if not os.path.exists(filename):
        raise FileNotFoundError(f'File not found: {filename}')

    # Open file
    with open(filename, 'rb') as f:
        # Get file size
        f.seek(0, 2)
        file_size = f.tell()

        # Validate start_byte
        if start_byte < 0:
            raise ValueError('start_byte must be >= 0')

        # Determine stop_byte
        if stop_byte is None:
            stop_byte = file_size - 1
        else:
            if stop_byte < start_byte:
                raise ValueError('stop_byte must be >= start_byte')

        # Seek to start position
        f.seek(start_byte)

        # Build output
        output_lines = []
        output_lines.append(f'Hex Dump: {filename}')
        output_lines.append(f'Byte Range: {start_byte} to {stop_byte}')
        output_lines.append(f'Size: {stop_byte - start_byte + 1} bytes')
        output_lines.append('')

        # Header
        output_lines.append('Offset      Hex' + ' ' * (bytes_per_line * 3 - 6) + 'ASCII')
        output_lines.append('-' * (10 + 2 + bytes_per_line * 3 + 2 + bytes_per_line))

        # Read and display
        current_byte = start_byte

        while current_byte <= stop_byte:
            # Calculate how many bytes to read
            bytes_to_read = min(bytes_per_line, stop_byte - current_byte + 1)

            # Read chunk
            chunk = f.read(bytes_to_read)

            if not chunk:
                break

            # Format offset
            offset_str = f'0x{current_byte:08x}'

            # Format hex
            hex_str = ' '.join(f'{b:02x}' for b in chunk)
            # Pad if less than full line
            hex_str = hex_str.ljust(bytes_per_line * 3 - 1)

            # Format ASCII
            ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)

            # Add line
            output_lines.append(f'{offset_str}  {hex_str}  {ascii_str}')

            current_byte += bytes_to_read

    return '\n'.join(output_lines)


def get_hex_diff_from_file_obj(file_obj1: BinaryIO, file_obj2: BinaryIO,
                                 start_byte: int = 0,
                                 stop_byte: Optional[int] = None) -> Tuple[bool, List[Tuple[int, bytes, bytes]]]:
    """
    Compare two file objects and return differing byte ranges.

    This is a lower-level utility that works with file objects instead of
    filenames, useful for in-memory comparisons.

    Args:
        file_obj1: First file object (must be opened in binary mode)
        file_obj2: Second file object (must be opened in binary mode)
        start_byte: Starting byte position (0-indexed), defaults to 0
        stop_byte: Stopping byte position (0-indexed), defaults to end of file

    Returns:
        Tuple of (files_identical, differences)
        - files_identical: True if files are identical in range, False otherwise
        - differences: List of (offset, chunk1, chunk2) for each differing chunk

    Examples:
        >>> with open('file1.bin', 'rb') as f1, open('file2.bin', 'rb') as f2:
        ...     identical, diffs = get_hex_diff_from_file_obj(f1, f2)
        ...     if not identical:
        ...         for offset, chunk1, chunk2 in diffs:
        ...             print(f'Difference at offset {offset}')
    """
    # Seek both to start
    file_obj1.seek(start_byte)
    file_obj2.seek(start_byte)

    # Determine stop_byte if not specified
    if stop_byte is None:
        # Get sizes
        pos1 = file_obj1.tell()
        pos2 = file_obj2.tell()

        file_obj1.seek(0, 2)
        size1 = file_obj1.tell()
        file_obj2.seek(0, 2)
        size2 = file_obj2.tell()

        stop_byte = max(size1, size2) - 1

        # Seek back
        file_obj1.seek(pos1)
        file_obj2.seek(pos2)

    # Compare in chunks
    chunk_size = 4096  # Larger chunks for efficiency
    current_byte = start_byte
    differences = []
    files_identical = True

    while current_byte <= stop_byte:
        bytes_to_read = min(chunk_size, stop_byte - current_byte + 1)

        chunk1 = file_obj1.read(bytes_to_read)
        chunk2 = file_obj2.read(bytes_to_read)

        if chunk1 != chunk2:
            files_identical = False
            differences.append((current_byte, chunk1, chunk2))

        if not chunk1 and not chunk2:
            break

        current_byte += bytes_to_read

    return files_identical, differences
