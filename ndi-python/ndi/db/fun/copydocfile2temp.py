"""
Copy a file from an NDI document to a temporary file.

This module provides functionality to extract binary files from NDI documents
and save them to temporary files for processing.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/copydocfile2temp.m
"""

import os
import tempfile
from typing import Tuple


def copydocfile2temp(
    doc,
    session,
    filename: str,
    extension: str
) -> Tuple[str, str]:
    """
    Copy a file from an ndi.document to a temporary file on the file system.

    Note: This function assumes the entire file can be read into memory at once.

    Args:
        doc: The ndi.document that has the file to be copied
        session: The ndi.session that the document belongs to
        filename: The filename of the file in the document to be copied
        extension: The extension of the filename (should include leading period, e.g., '.dat')

    Returns:
        tuple: (temp_filename, temp_filename_without_ext)
            - temp_filename: Full path to the temporary file created
            - temp_filename_without_ext: Path without the extension

    Raises:
        FileNotFoundError: If the file doesn't exist in the document
        IOError: If the file cannot be read or written

    Example:
        >>> from ndi.session import Session
        >>> from ndi.document import Document
        >>> session = Session('/path/to/session')
        >>> doc = session.database_read('doc_id_here')
        >>> temp_file, temp_base = copydocfile2temp(doc, session, 'data.bin', '.bin')
        >>> # Use the temporary file
        >>> with open(temp_file, 'rb') as f:
        ...     data = f.read()
        >>> # Clean up when done
        >>> os.remove(temp_file)

    Notes:
        - Creates a temporary file with a unique name
        - The calling program should delete the file when finished using os.remove()
        - Could be expanded to include a cache to avoid redundant copies
        - Reads entire file into memory, so not suitable for very large files
    """
    # Generate temporary filename
    fd, temp_name_without_ext = tempfile.mkstemp(suffix='', prefix='ndi_')
    os.close(fd)  # Close the file descriptor, we'll write manually
    os.remove(temp_name_without_ext)  # Remove the file, we'll recreate with extension

    temp_name = temp_name_without_ext + extension

    try:
        # Open the binary file from the document
        f = session.database_openbinarydoc(doc, filename)

        # Read all data
        if hasattr(f, 'fread'):
            # If it's an ndi.binarydoc object
            data = f.fread()
        elif hasattr(f, 'read'):
            # If it's a file-like object
            data = f.read()
        else:
            raise IOError(f"Cannot read from file object of type {type(f)}")

        # Write to temporary file
        with open(temp_name, 'wb') as fid:
            if isinstance(data, bytes):
                fid.write(data)
            elif isinstance(data, (list, tuple)):
                # Convert list/tuple to bytes
                fid.write(bytes(data))
            else:
                # Try to convert to bytes
                try:
                    fid.write(bytes(data))
                except Exception as e:
                    raise IOError(f"Cannot convert data to bytes: {e}")

        # Close the binary doc if it has a close method
        if hasattr(f, 'close') and callable(f.close):
            f.close()

        return temp_name, temp_name_without_ext

    except Exception as e:
        # Clean up on error
        if os.path.exists(temp_name):
            try:
                os.remove(temp_name)
            except:
                pass
        if os.path.exists(temp_name_without_ext):
            try:
                os.remove(temp_name_without_ext)
            except:
                pass
        raise IOError(f"Failed to copy document file to temp: {e}") from e
