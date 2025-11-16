"""
Interactive utility to create a new NDI database.

This module provides an interactive command-line interface for creating
new NDI databases and managing dataset information.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/create_new_database.m
"""

import sys
from typing import Optional, Tuple


def create_new_database(
    interactive: bool = True,
    existing_dataset: Optional[bool] = None,
    dataset_id: Optional[str] = None
) -> Tuple[bool, Optional[str]]:
    """
    Create a new database interactively or programmatically.

    This function guides the user through creating a new NDI database,
    optionally associating it with an existing dataset.

    Args:
        interactive: If True, prompt user for input. If False, use provided arguments.
        existing_dataset: Whether to add to an existing dataset (None prompts if interactive=True)
        dataset_id: The dataset ID to use (None prompts if interactive=True and existing_dataset=True)

    Returns:
        tuple: (success, dataset_id)
            - success: True if database creation settings were configured
            - dataset_id: The dataset ID if specified, None otherwise

    Example:
        >>> # Interactive mode
        >>> success, dataset_id = create_new_database()
        >>> # Non-interactive mode
        >>> success, dataset_id = create_new_database(
        ...     interactive=False,
        ...     existing_dataset=True,
        ...     dataset_id='my_dataset_123'
        ... )

    Notes:
        - In MATLAB, this uses GUI dialogs (inputdlg)
        - Python version uses command-line prompts
        - Returns configuration settings for database creation
        - Does not actually create the database files (use opendatabase for that)
    """

    if interactive:
        # Prompt user for input
        print("\n=== NDI Database Creation ===")

        # Ask if adding to existing dataset
        if existing_dataset is None:
            while True:
                response = input("Are you adding to an existing dataset? (y/n): ").strip().lower()
                if response in ['y', 'yes']:
                    existing_dataset = True
                    break
                elif response in ['n', 'no']:
                    existing_dataset = False
                    break
                else:
                    print("Please enter 'y' or 'n'")

        # If adding to existing dataset, get dataset ID
        if existing_dataset and dataset_id is None:
            while True:
                dataset_id = input("Please enter your dataset ID: ").strip()
                if dataset_id:
                    break
                else:
                    print("Dataset ID cannot be empty")

        # Display configuration
        print("\n=== Configuration ===")
        if existing_dataset:
            print(f"Adding to existing dataset: {dataset_id}")
        else:
            print("Creating standalone database (not part of existing dataset)")
            dataset_id = None

        return True, dataset_id

    else:
        # Non-interactive mode
        if existing_dataset is None:
            raise ValueError("existing_dataset must be specified in non-interactive mode")

        if existing_dataset and dataset_id is None:
            raise ValueError("dataset_id must be specified when existing_dataset=True")

        return True, dataset_id


def create_new_database_simple(dataset_id: Optional[str] = None) -> Tuple[bool, Optional[str]]:
    """
    Simplified non-interactive database creation.

    Args:
        dataset_id: Optional dataset ID to associate with

    Returns:
        tuple: (success, dataset_id)

    Example:
        >>> # Create standalone database
        >>> success, _ = create_new_database_simple()
        >>> # Create database for dataset
        >>> success, dataset_id = create_new_database_simple('my_dataset_123')
    """
    if dataset_id:
        return create_new_database(
            interactive=False,
            existing_dataset=True,
            dataset_id=dataset_id
        )
    else:
        return create_new_database(
            interactive=False,
            existing_dataset=False,
            dataset_id=None
        )
