"""
NDI Dataset Dir - Directory-based dataset implementation.

This module provides a directory-based implementation of the Dataset class,
storing dataset data in a file system directory.

Ported from MATLAB: src/ndi/+ndi/+dataset/dir.m
"""

from pathlib import Path
from typing import Optional, List
import warnings

from .dataset import Dataset
from ..session import SessionDir
from ..query import Query
from ..document import Document


class Dir(Dataset):
    """
    Directory-based Dataset implementation.

    Stores dataset data in a file system directory, with an internal
    session for dataset-level documents and references to contained sessions.

    Attributes:
        path (Path): File path of the dataset directory
    """

    def __init__(
        self,
        reference_or_path: str,
        path: Optional[str] = None,
        docs: Optional[List[Document]] = None
    ):
        """
        Create a new directory-based dataset or open an existing one.

        Usage:
            # Create new dataset
            dataset = Dir('my_dataset', '/path/to/dataset')

            # Open existing dataset
            dataset = Dir('/path/to/dataset')

        Args:
            reference_or_path: Reference name (if path provided) or path (if no path)
            path: Directory path for dataset (optional if reference_or_path is path)
            docs: Hidden option for loading with predefined documents

        Example:
            >>> from ndi.dataset import Dir
            >>> # Create new dataset
            >>> dataset = Dir('experiment1', '/data/exp1')
            >>> # Open existing dataset
            >>> dataset2 = Dir('/data/exp1')

        See Also:
            ndi.dataset.Dataset
        """
        # Handle different constructor forms
        if path is None:
            # Single argument form: Dir(path)
            path = reference_or_path
            reference = 'temp'
        else:
            # Two argument form: Dir(reference, path)
            reference = reference_or_path

        # Initialize parent class
        super().__init__(reference)

        # Store path
        self.path = Path(path)

        # Create or open session
        if docs is None:
            # Normal creation
            self.session = SessionDir(str(self.path), reference)
        else:
            # Hidden third option - load with predefined documents
            # Suppress warnings during this operation
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")

                # Create session
                self.session = SessionDir(str(self.path), reference)

                # Add documents directly to database
                # Note: This is a hack matching MATLAB behavior
                if hasattr(self.session, 'database') and hasattr(self.session.database, 'add'):
                    self.session.database.add(docs)

                # Recreate session to ensure consistency
                self.session = SessionDir(str(self.path), reference)

        # Check for existing dataset session info to restore dataset ID
        q = Query('', 'isa', 'dataset_session_info')
        d = self.session.database_search(q)

        if d:
            if len(d) > 1:
                raise RuntimeError(
                    'More than one dataset_session_info object found in dataset.'
                )

            # Found existing dataset - restore session with correct ID
            session_id = d[0].document_properties.get('base', {}).get('session_id', '')

            if session_id:
                # Look for session document to get reference
                q2 = (
                    Query('', 'isa', 'session') &
                    Query('base.session_id', 'exact_string', session_id)
                )
                d2 = self.session.database_search(q2)

                if d2:
                    ref = d2[0].document_properties.get('session', {}).get('reference', reference)

                    # Recreate session with correct reference and ID
                    self.session = SessionDir(str(self.path), ref, session_id)

    def _create_session_with_id(
        self,
        reference: str,
        path: str,
        session_id: str
    ) -> SessionDir:
        """
        Create a SessionDir with a specific session ID.

        This is a helper method to recreate sessions with known IDs.

        Args:
            reference: Session reference
            path: Session path
            session_id: Specific session ID to use

        Returns:
            SessionDir: Session with specified ID
        """
        # Create session
        session = SessionDir(path, reference)

        # Override the session ID (matching MATLAB behavior)
        # This is a bit of a hack but necessary for reopening datasets
        session.identifier = session_id

        return session

    @staticmethod
    def dataset_erase(ndi_dataset_dir_obj: 'Dir', areyousure: str = 'no') -> None:
        """
        Delete the entire dataset database folder.

        WARNING: This permanently deletes all dataset data. Use with extreme care!

        Args:
            ndi_dataset_dir_obj: Dataset.Dir object to erase
            areyousure: Must be 'yes' to proceed

        Example:
            >>> dataset = Dir('/path/to/dataset')
            >>> Dir.dataset_erase(dataset, 'yes')  # DANGER!

        Note:
            This is a static method but takes the dataset object as first parameter.
        """
        import shutil

        if not isinstance(ndi_dataset_dir_obj, Dir):
            raise TypeError("First argument must be a ndi.dataset.Dir object")

        if areyousure.lower() == 'yes':
            # Remove ndi_database directory (matching Python DirectoryDatabase)
            ndi_dir = ndi_dataset_dir_obj.path / 'ndi_database'
            if ndi_dir.exists():
                shutil.rmtree(ndi_dir)
                print(f"Dataset database folder erased: {ndi_dir}")
            else:
                print(f"No database folder found at: {ndi_dir}")
        else:
            print("Not erasing dataset directory folder because user did not indicate they are sure.")

    def __repr__(self) -> str:
        """String representation."""
        return (
            f"Dir(path='{self.path}', "
            f"reference='{self.session.reference if self.session else 'unknown'}', "
            f"id='{self.id()[:8] if self.session else 'unknown'}...', "
            f"sessions={len(self.session_info)})"
        )
