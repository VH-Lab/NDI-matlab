"""
Initialize the database hierarchy for NDI.

This module defines the priority order and configuration for different
database types that NDI can use.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/databasehierarchyinit.m
"""

from typing import List, Dict, Any


def databasehierarchyinit() -> List[Dict[str, Any]]:
    """
    Initialize the list of databases to try in priority order.

    Returns a list of database type configurations, defining which database
    backends are available and in what priority order they should be tried.

    Returns:
        List of dictionaries, each containing:
            - name: Database class name
            - extension: File extension or marker
            - class_path: Python import path to the class
            - priority: Priority level (lower = higher priority)

    Example:
        >>> hierarchy = databasehierarchyinit()
        >>> for db_type in hierarchy:
        ...     print(f"{db_type['name']}: priority {db_type['priority']}")

    Notes:
        - Databases are tried in priority order (lower priority number = tried first)
        - SQLiteDatabase has highest priority (best performance)
        - MATLABDumbJSONDB2 is second (good balance of features and simplicity)
        - DirectoryDatabase is fallback (maximum compatibility)
    """
    from ndi.database import SQLiteDatabase, MATLABDumbJSONDB2, DirectoryDatabase

    # Define database hierarchy in priority order
    hierarchy = [
        {
            'name': 'SQLiteDatabase',
            'extension': '.ndi.db',
            'class': SQLiteDatabase,
            'class_path': 'ndi.database.sqlite.SQLiteDatabase',
            'priority': 1,
            'description': 'SQLite-based database with SQL query optimization',
            'features': ['sql_queries', 'transactions', 'binary_files', 'indexing'],
        },
        {
            'name': 'MATLABDumbJSONDB2',
            'extension': '.ndi',
            'class': MATLABDumbJSONDB2,
            'class_path': 'ndi.database.matlabdumbjsondb2.MATLABDumbJSONDB2',
            'priority': 2,
            'description': 'JSON-based database with binary file management',
            'features': ['human_readable', 'binary_files', 'simple'],
        },
        {
            'name': 'DirectoryDatabase',
            'extension': '.ndi',
            'class': DirectoryDatabase,
            'class_path': 'ndi.database.base.DirectoryDatabase',
            'priority': 3,
            'description': 'Simple directory-based database (legacy)',
            'features': ['human_readable', 'simple', 'legacy_compatible'],
        },
    ]

    return hierarchy


def get_database_by_name(name: str) -> Dict[str, Any]:
    """
    Get database configuration by name.

    Args:
        name: Database class name (e.g., 'SQLiteDatabase')

    Returns:
        Database configuration dictionary

    Raises:
        ValueError: If database name is not found

    Example:
        >>> config = get_database_by_name('SQLiteDatabase')
        >>> print(config['description'])
    """
    hierarchy = databasehierarchyinit()

    for db_config in hierarchy:
        if db_config['name'] == name:
            return db_config

    raise ValueError(f"Database type '{name}' not found in hierarchy")


def get_database_by_priority(priority: int) -> Dict[str, Any]:
    """
    Get database configuration by priority level.

    Args:
        priority: Priority level (1 = highest priority)

    Returns:
        Database configuration dictionary

    Raises:
        ValueError: If priority level is not found

    Example:
        >>> config = get_database_by_priority(1)
        >>> print(config['name'])  # 'SQLiteDatabase'
    """
    hierarchy = databasehierarchyinit()

    for db_config in hierarchy:
        if db_config['priority'] == priority:
            return db_config

    raise ValueError(f"No database with priority {priority} found")


def get_default_database() -> Dict[str, Any]:
    """
    Get the default (highest priority) database configuration.

    Returns:
        Database configuration dictionary for the default database type

    Example:
        >>> config = get_default_database()
        >>> print(config['name'])  # 'SQLiteDatabase'
    """
    hierarchy = databasehierarchyinit()
    # Return the one with lowest priority number (highest priority)
    return min(hierarchy, key=lambda x: x['priority'])
