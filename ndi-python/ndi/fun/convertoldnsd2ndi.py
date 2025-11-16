"""
Convert old 'NSD' session directories to 'NDI' format.

This module provides functionality to convert legacy NSD (Neuroscience Data)
session directories to the new NDI (Neuroscience Data Interface) naming convention.

Ported from MATLAB: ndi.fun.convertoldnsd2ndi
"""

import os
import shutil
import re
from pathlib import Path
from typing import List, Tuple
import warnings


def convertoldnsd2ndi(pathname: str, dry_run: bool = False) -> Tuple[int, int]:
    """
    Convert an old 'nsd' session to 'ndi' naming convention.

    This function performs the following irreversible changes:
    1. Any instance of 'nsd' in a filename is changed to 'ndi'
    2. Any instance of 'NSD' in a filename is changed to 'NDI'
    3. All instances of 'nsd' in .m, .json, .txt, *object_* files are replaced with 'ndi'
    4. All instances of 'NSD' in .m, .json, .txt, *object_* files are replaced with 'NDI'

    **WARNING**: This function makes irreversible changes to the directory structure
    and file contents. It is strongly recommended to:
    - Make a backup before running
    - Use dry_run=True first to preview changes

    Args:
        pathname: Path to the NSD session directory to convert
        dry_run: If True, only report what would be changed without making changes

    Returns:
        tuple: (files_renamed, files_modified) - counts of files changed

    Raises:
        ValueError: If pathname does not exist or is not a directory
        PermissionError: If insufficient permissions to modify files

    Example:
        >>> # Preview changes first
        >>> files_renamed, files_modified = convertoldnsd2ndi('/path/to/session', dry_run=True)
        >>> print(f"Would rename {files_renamed} files, modify {files_modified} files")
        >>>
        >>> # Then actually convert
        >>> convertoldnsd2ndi('/path/to/session', dry_run=False)

    Note:
        This function is deprecated and should be irrelevant shortly as everyone
        uses 'NDI' instead of 'NSD'. It's maintained for legacy data migration only.

    MATLAB Source: ndi.fun.convertoldnsd2ndi
    """
    # Validate input
    path = Path(pathname)
    if not path.exists():
        raise ValueError(f"Path does not exist: {pathname}")
    if not path.is_dir():
        raise ValueError(f"Path is not a directory: {pathname}")

    # Issue deprecation warning
    warnings.warn(
        "convertoldnsd2ndi is deprecated. This function is for legacy data "
        "migration only. All new sessions should use 'NDI' naming convention.",
        DeprecationWarning,
        stacklevel=2
    )

    files_renamed = 0
    files_modified = 0

    print(f"{'[DRY RUN] ' if dry_run else ''}Converting NSD session to NDI: {pathname}")
    print(f"{'[DRY RUN] ' if dry_run else ''}WARNING: This will make irreversible changes!")

    # Step 1: Rename directories (bottom-up to avoid path issues)
    # We need to do this in multiple passes until no more renames are needed
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Step 1: Renaming directories...")
    dir_renames = _rename_directories(path, dry_run)
    files_renamed += dir_renames
    print(f"  Renamed {dir_renames} directories")

    # Step 2: Rename files containing 'nsd' or 'NSD'
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Step 2: Renaming files...")
    file_renames = _rename_files(path, dry_run)
    files_renamed += file_renames
    print(f"  Renamed {file_renames} files")

    # Step 3: Replace content in text files
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Step 3: Replacing content in files...")
    content_changes = _replace_file_contents(path, dry_run)
    files_modified += content_changes
    print(f"  Modified {content_changes} files")

    print(f"\n{'[DRY RUN] ' if dry_run else ''}Conversion complete!")
    print(f"  Total files renamed: {files_renamed}")
    print(f"  Total files modified: {files_modified}")

    return files_renamed, files_modified


def _rename_directories(root_path: Path, dry_run: bool) -> int:
    """
    Rename directories containing 'nsd' or 'NSD' to 'ndi' or 'NDI'.

    Processes directories bottom-up to avoid path issues.

    Args:
        root_path: Root directory to search
        dry_run: If True, don't actually rename

    Returns:
        int: Number of directories renamed
    """
    renamed_count = 0
    done = False

    # Keep renaming until no more changes are needed
    while not done:
        # Get all directories, sorted by depth (deepest first)
        all_dirs = sorted(
            [d for d in root_path.rglob('*') if d.is_dir()],
            key=lambda p: len(p.parts),
            reverse=True
        )

        found_rename = False
        for dir_path in all_dirs:
            dir_name = dir_path.name

            # Check if directory name contains 'nsd' or 'NSD'
            new_name = dir_name.replace('nsd', 'ndi').replace('NSD', 'NDI')

            if new_name != dir_name:
                new_path = dir_path.parent / new_name

                if dry_run:
                    print(f"  Would rename: {dir_path.relative_to(root_path)} -> {new_name}")
                else:
                    shutil.move(str(dir_path), str(new_path))
                    print(f"  Renamed: {dir_path.relative_to(root_path)} -> {new_name}")

                renamed_count += 1
                found_rename = True
                break  # Restart search with new directory structure

        if not found_rename:
            done = True

    return renamed_count


def _rename_files(root_path: Path, dry_run: bool) -> int:
    """
    Rename files containing 'nsd' or 'NSD' to 'ndi' or 'NDI'.

    Args:
        root_path: Root directory to search
        dry_run: If True, don't actually rename

    Returns:
        int: Number of files renamed
    """
    renamed_count = 0

    # Get all files
    all_files = [f for f in root_path.rglob('*') if f.is_file()]

    for file_path in all_files:
        file_name = file_path.name

        # Check if filename contains 'nsd' or 'NSD'
        new_name = file_name.replace('nsd', 'ndi').replace('NSD', 'NDI')

        if new_name != file_name:
            new_path = file_path.parent / new_name

            # Check if target already exists
            if new_path.exists() and not dry_run:
                print(f"  WARNING: Target exists, skipping: {new_path.relative_to(root_path)}")
                continue

            if dry_run:
                print(f"  Would rename: {file_path.relative_to(root_path)} -> {new_name}")
            else:
                shutil.move(str(file_path), str(new_path))
                print(f"  Renamed: {file_path.relative_to(root_path)} -> {new_name}")

            renamed_count += 1

    return renamed_count


def _replace_file_contents(root_path: Path, dry_run: bool) -> int:
    """
    Replace 'nsd' and 'NSD' with 'ndi' and 'NDI' in file contents.

    Processes: .txt, .m, .json, .ndi files, and *object_* files

    Args:
        root_path: Root directory to search
        dry_run: If True, don't actually modify files

    Returns:
        int: Number of files modified
    """
    modified_count = 0

    # Define file patterns to process
    file_patterns = [
        '*.txt',
        '*.m',
        '*.json',
        '*.ndi',
        '*object_*'  # Any file with 'object_' in the name
    ]

    # Collect all matching files
    files_to_process = set()
    for pattern in file_patterns:
        files_to_process.update(root_path.rglob(pattern))

    # Process each file
    for file_path in files_to_process:
        if not file_path.is_file():
            continue

        try:
            # Read file content (try UTF-8, fallback to latin-1 for binary-ish files)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                encoding = 'utf-8'
            except UnicodeDecodeError:
                with open(file_path, 'r', encoding='latin-1') as f:
                    content = f.read()
                encoding = 'latin-1'

            # Replace nsd -> ndi and NSD -> NDI
            new_content = content.replace('nsd', 'ndi').replace('NSD', 'NDI')

            # Check if any changes were made
            if new_content != content:
                if dry_run:
                    # Count how many replacements would be made
                    nsd_count = content.count('nsd')
                    NSD_count = content.count('NSD')
                    print(f"  Would modify: {file_path.relative_to(root_path)} "
                          f"({nsd_count} 'nsd', {NSD_count} 'NSD')")
                else:
                    # Write modified content back
                    with open(file_path, 'w', encoding=encoding) as f:
                        f.write(new_content)

                    nsd_count = content.count('nsd')
                    NSD_count = content.count('NSD')
                    print(f"  Modified: {file_path.relative_to(root_path)} "
                          f"({nsd_count} 'nsd', {NSD_count} 'NSD')")

                modified_count += 1

        except (PermissionError, OSError) as e:
            print(f"  ERROR: Could not process {file_path.relative_to(root_path)}: {e}")

    return modified_count


# Convenience alias matching MATLAB naming
convert_old_nsd_to_ndi = convertoldnsd2ndi


if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("Usage: python -m ndi.fun.convertoldnsd2ndi <pathname> [--dry-run]")
        print("\nConvert old 'NSD' session to 'NDI' naming convention.")
        print("\nOptions:")
        print("  --dry-run    Show what would be changed without making changes")
        print("\nWARNING: This makes irreversible changes! Make a backup first!")
        sys.exit(1)

    pathname = sys.argv[1]
    dry_run = '--dry-run' in sys.argv

    try:
        files_renamed, files_modified = convertoldnsd2ndi(pathname, dry_run=dry_run)

        if not dry_run:
            print("\nConversion successful!")
        else:
            print(f"\nDry run complete. Run without --dry-run to apply changes.")

    except Exception as e:
        print(f"\nERROR: {e}")
        sys.exit(1)
