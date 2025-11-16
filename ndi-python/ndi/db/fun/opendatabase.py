"""
Open or create a database for an NDI session.

This module provides functionality to open an existing database or create
a new one based on the database hierarchy.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/opendatabase.m
"""

import os
from typing import Optional


def opendatabase(database_path: str, session_unique_reference: str = '12345'):
    """
    Open the database associated with a session.

    Searches the file path for any known databases in the database hierarchy.
    If it finds a database, it opens and returns it. If no database is found,
    it tries to create a new database following the hierarchy order.

    Args:
        database_path: Full path to the database directory
        session_unique_reference: Unique reference for the session (default: '12345')

    Returns:
        Database object if successful, None otherwise

    Example:
        >>> db = opendatabase('/path/to/session', 'my_session_ref')
        >>> if db:
        ...     print(f"Database opened: {type(db)}")
        ... else:
        ...     print("No database found or created")

    Notes:
        - Searches for databases in order defined by database hierarchy
        - Tries to open existing database first (looks for matching files)
        - If no database found, creates new one using first available type
        - Database hierarchy defines supported database types and their priority
        - Returns None if no database can be opened or created
    """
    from ndi.database import DirectoryDatabase, SQLiteDatabase, MATLABDumbJSONDB2

    db = None

    # Ensure path exists
    if not os.path.exists(database_path):
        try:
            os.makedirs(database_path, exist_ok=True)
        except OSError:
            return None

    # Define database hierarchy (priority order)
    # This is Python's version of ndi.common.getDatabaseHierarchy()
    database_hierarchy = [
        {
            'name': 'SQLiteDatabase',
            'extension': '.ndi.db',
            'class': SQLiteDatabase,
        },
        {
            'name': 'MATLABDumbJSONDB2',
            'extension': '.ndi',  # Uses directory structure
            'class': MATLABDumbJSONDB2,
        },
        {
            'name': 'DirectoryDatabase',
            'extension': '.ndi',  # Uses directory structure
            'class': DirectoryDatabase,
        },
    ]

    # Try to find and open existing database
    for db_type in database_hierarchy:
        extension = db_type['extension']

        if extension == '.ndi.db':
            # Look for SQLite database file
            db_files = [f for f in os.listdir(database_path) if f.endswith(extension)]
            if db_files:
                if len(db_files) > 1:
                    raise ValueError(f"Too many matching database files: {db_files}")
                db_file = os.path.join(database_path, db_files[0])
                try:
                    db = db_type['class'](database_path, session_unique_reference)
                    return db
                except Exception as e:
                    print(f"Failed to open {db_type['name']}: {e}")
                    continue

        elif extension == '.ndi':
            # Check if this looks like a directory-based database
            # (has appropriate structure)
            if os.path.isdir(database_path):
                # Check for database indicators
                has_ndi_dir = os.path.exists(os.path.join(database_path, '.ndi'))
                has_docs = any(
                    fname.endswith('.json')
                    for fname in os.listdir(database_path)
                    if os.path.isfile(os.path.join(database_path, fname))
                )

                if has_ndi_dir or has_docs:
                    try:
                        db = db_type['class'](database_path, session_unique_reference)
                        return db
                    except Exception as e:
                        print(f"Failed to open {db_type['name']}: {e}")
                        continue

    # No existing database found, try to create a new one
    if db is None:
        for db_type in database_hierarchy:
            try:
                db = db_type['class'](database_path, session_unique_reference)
                print(f"Created new {db_type['name']} at {database_path}")
                return db
            except Exception as e:
                print(f"Failed to create {db_type['name']}: {e}")
                continue

    return db
