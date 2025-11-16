"""
NDI Session Maker - Create and manage NDI sessions from tabular data.

This module provides SessionMaker class for creating or loading NDI sessions
based on variable tables containing session references and paths.
"""

from typing import List, Dict, Any, Optional, Set
import os
import logging
import pandas as pd
import numpy as np


class SessionMaker:
    """
    Manages session creation setup based on a variable table.

    The SessionMaker class facilitates the setup and creation of
    ndi.session.dir objects. It identifies unique sessions, handles
    existing session directories (with an option to overwrite),
    and provides mechanisms to associate DAQ systems with these sessions.

    Attributes:
        path (str): Base directory path where session folders are located or will be created.
        variable_table (pd.DataFrame): Input table containing session definition information.
                                       Must contain 'SessionRef' and 'SessionPath' columns.
        sessions (List): List holding the created/loaded ndi.session.dir objects.
        table_ind (np.ndarray): Array mapping rows of the input 'variable_table' to session
                                indices in 'sessions'. Invalid rows will have NaN entries.
        daq_systems (List[Dict]): List of dictionaries holding DAQ system information for
                                   each session. Contains 'filenavigator' and 'daqreader' keys.

    Example:
        >>> import pandas as pd
        >>> from ndi.setup.makers import SessionMaker
        >>>
        >>> # Create a variable table
        >>> data = {
        ...     'SessionRef': ['exp001', 'exp001', 'exp002'],
        ...     'SessionPath': ['session1', 'session1', 'session2'],
        ...     'EpochID': ['e1', 'e2', 'e1']
        ... }
        >>> variable_table = pd.DataFrame(data)
        >>>
        >>> # Create SessionMaker
        >>> maker = SessionMaker('/path/to/sessions', variable_table)
        >>> print(f"Created {len(maker.sessions)} sessions")
        Created 2 sessions
        >>>
        >>> # Access sessions
        >>> for i, session in enumerate(maker.sessions):
        ...     print(f"Session {i}: {session.reference}")
    """

    def __init__(self,
                 path: str,
                 variable_table: pd.DataFrame,
                 overwrite: bool = False,
                 non_nan_variable_names: Optional[List[str]] = None,
                 show_progress: bool = True):
        """
        Initialize SessionMaker and create/load sessions.

        Args:
            path: The absolute path to the base directory containing session folders.
                  Must be an existing folder.
            variable_table: A DataFrame defining the sessions. Must contain
                           'SessionRef' and 'SessionPath' columns.
            overwrite: If False, existing sessions are loaded without modification.
                      If True, existing NDI session databases will be erased and recreated.
                      Default: False.
            non_nan_variable_names: Column names in variable_table whose values must not
                                   be NaN for a valid session to be created. Default: None.
            show_progress: Whether to display progress. Default: True.

        Raises:
            ValueError: If path doesn't exist or variable_table lacks required columns.
        """
        from ...util.table import identify_valid_rows
        from ...gui import ProgressTracker, ConsoleProgressMonitor

        # Validate inputs
        if not os.path.isdir(path):
            raise ValueError(f"Path does not exist: {path}")

        if 'SessionRef' not in variable_table.columns:
            raise ValueError("variable_table must contain 'SessionRef' column")
        if 'SessionPath' not in variable_table.columns:
            raise ValueError("variable_table must contain 'SessionPath' column")

        # Assign properties
        self.path = path
        self.variable_table = variable_table
        self.sessions = []
        self.table_ind = np.full(len(variable_table), np.nan)
        self.daq_systems = []

        # Get valid epoch rows
        if non_nan_variable_names is None:
            non_nan_variable_names = []

        valid_ind = identify_valid_rows(variable_table, non_nan_variable_names)

        if not any(valid_ind):
            logging.warning("No valid rows found in variable_table")
            return

        # Extract SessionRef values from valid rows
        valid_session_refs = variable_table.loc[valid_ind, 'SessionRef'].values

        # Find unique session references
        # Using pandas to match MATLAB's unique(..., 'stable') behavior
        seen = {}
        session_refs = []
        session_ind_unique = []
        table_ind_map = []

        for i, ref in enumerate(valid_session_refs):
            if ref not in seen:
                seen[ref] = len(session_refs)
                session_refs.append(ref)
                session_ind_unique.append(i)
            table_ind_map.append(seen[ref])

        # Get indices in original variable_table for first occurrence of each unique session
        valid_indices = np.where(valid_ind)[0]
        first_occurrence_ind = valid_indices[session_ind_unique]

        # Populate table_ind property
        self.table_ind[valid_indices] = table_ind_map

        # Create or load NDI session objects
        logging.info(f"Creating/loading {len(session_refs)} session(s)...")

        # Setup progress monitoring
        progress_tracker = None
        progress_monitor = None
        if show_progress and len(session_refs) > 0:
            progress_tracker = ProgressTracker()
            progress_monitor = ConsoleProgressMonitor("Creating Session(s)", tracker=progress_tracker)
            progress_tracker.start()

        for i, session_ref in enumerate(session_refs):
            # Get the full path for the current session
            session_path = os.path.join(
                path,
                variable_table.loc[first_occurrence_ind[i], 'SessionPath']
            )

            # Import here to avoid circular dependency
            from ...session import Session

            # Check if session exists
            if Session.exists(session_path):
                # Session exists: Load it
                session = Session(session_path)

                if overwrite:
                    # Delete existing session database
                    Session.database_erase(session, 'yes')
                    # Create new session object
                    session = Session(session_ref, session_path)
                    logging.info(f"Session {i+1}/{len(session_refs)}: Recreated '{session_ref}'")
                else:
                    logging.info(f"Session {i+1}/{len(session_refs)}: Loaded existing '{session_ref}'")
            else:
                # Session does not exist: Create it
                session = Session(session_ref, session_path)
                logging.info(f"Session {i+1}/{len(session_refs)}: Created new '{session_ref}'")

            self.sessions.append(session)

            # Initialize DAQ systems structure for this session
            self.daq_systems.append({
                'filenavigator': [],
                'daqreader': []
            })

            # Update progress
            if progress_tracker:
                progress_tracker.update_progress(
                    (i + 1) / len(session_refs),
                    f"Session {i+1}/{len(session_refs)}: {session_ref}"
                )

            # Close any open database connections (if applicable)
            # Note: In Python, this is handled by context managers/garbage collection

        # Mark progress complete
        if progress_tracker:
            progress_tracker.mark_complete()

    def add_daq_system(self,
                      session_index: int,
                      filenavigator: Any,
                      daqreader: Any) -> None:
        """
        Add a DAQ system to a specific session.

        Args:
            session_index: Index of the session in self.sessions.
            filenavigator: File navigator object for the DAQ system.
            daqreader: DAQ reader object for the DAQ system.

        Raises:
            IndexError: If session_index is out of range.
        """
        if session_index < 0 or session_index >= len(self.sessions):
            raise IndexError(f"Session index {session_index} out of range")

        self.daq_systems[session_index]['filenavigator'].append(filenavigator)
        self.daq_systems[session_index]['daqreader'].append(daqreader)

        logging.debug(f"Added DAQ system to session {session_index}")

    def get_session_by_ref(self, session_ref: str) -> Optional[Any]:
        """
        Get a session object by its reference string.

        Args:
            session_ref: The session reference to search for.

        Returns:
            The session object if found, None otherwise.
        """
        for session in self.sessions:
            if session.reference == session_ref:
                return session
        return None

    def get_session_index(self, table_row: int) -> Optional[int]:
        """
        Get the session index for a given variable_table row.

        Args:
            table_row: Row index in variable_table.

        Returns:
            Session index if valid, None if invalid row.
        """
        if table_row < 0 or table_row >= len(self.table_ind):
            return None

        idx = self.table_ind[table_row]
        if np.isnan(idx):
            return None

        return int(idx)

    def __repr__(self) -> str:
        """String representation of SessionMaker."""
        return (f"SessionMaker(path='{self.path}', "
                f"sessions={len(self.sessions)}, "
                f"table_rows={len(self.variable_table)})")
