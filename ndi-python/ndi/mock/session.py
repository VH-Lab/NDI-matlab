"""
Mock Session - A mock session class for testing.

This module provides a mock session that can be used for testing NDI functionality
without requiring real data files.

Ported from MATLAB: src/ndi/+ndi/+session/mock.m
"""

import tempfile
import shutil
from pathlib import Path
from typing import Optional

from ..session import SessionDir
from ..subject import Subject
from ..query import Query


class MockSession(SessionDir):
    """
    Mock session for testing purposes.

    Creates a temporary session with:
    - A temporary path
    - A fake subject ('anteater27@nosuchlab.org')
    - Mock DAQ device (if test data available)
    - Single epoch (if test data available)

    This class is useful for testing NDI functionality without requiring
    actual experimental data files.

    Example:
        >>> from ndi.mock import MockSession
        >>> session = MockSession()
        >>> # Use session for testing
        >>> session.cleanup()  # Clean up when done
    """

    def __init__(self, reference: str = 'mock_test', cleanup_on_delete: bool = True):
        """
        Create a new mock session for testing.

        Args:
            reference: Reference name for the session (default: 'mock_test')
            cleanup_on_delete: Automatically cleanup temporary files on deletion

        Example:
            >>> session = MockSession()
            >>> print(session.id())
            >>> session.cleanup()
        """
        # Create temporary directory
        self.temp_dir = tempfile.mkdtemp(prefix='ndi_mock_')
        self._cleanup_on_delete = cleanup_on_delete

        # Initialize as SessionDir
        super().__init__(self.temp_dir, reference)

        # Clear any existing data
        self.database_clear('yes')

        # Try to clear DAQ systems if method exists
        try:
            self.daqsystem_clear()
        except AttributeError:
            pass  # daqsystem_clear may not be implemented yet

        # Add mock subject
        self._add_mock_subject()

        # Note: We don't add mock DAQ device or data files here to keep
        # the mock session simple and not require test data files.
        # Subclasses or specific tests can add those if needed.

    def _add_mock_subject(self) -> None:
        """
        Add a mock subject to the session.

        Creates a fake subject with ID 'anteater27@nosuchlab.org'
        """
        # Check if subject already exists
        query = Query('subject.local_identifier', 'exact_string', 'anteater27@nosuchlab.org')
        existing = self.database_search(query)

        if not existing:
            # Create mock subject (pass self as session)
            subject = Subject(self, 'anteater27@nosuchlab.org')
            doc = subject.newdocument()
            doc = doc.set_session_id(self.id())
            self.database_add(doc)

    def cleanup(self) -> None:
        """
        Clean up temporary directory and files.

        Should be called when done with the mock session to free resources.

        Example:
            >>> session = MockSession()
            >>> # ... use session ...
            >>> session.cleanup()
        """
        if hasattr(self, 'temp_dir') and Path(self.temp_dir).exists():
            shutil.rmtree(self.temp_dir, ignore_errors=True)

    def __del__(self):
        """Cleanup on deletion if enabled."""
        if self._cleanup_on_delete:
            try:
                self.cleanup()
            except:
                pass  # Ignore errors during cleanup

    def __repr__(self) -> str:
        """String representation."""
        return f"MockSession(path='{self.temp_dir}', reference='{self.reference}', id='{self.id()[:8]}...')"
