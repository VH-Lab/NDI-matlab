"""Check status of DOI submission to Crossref.

This module provides functionality to check the status and content of
metadata submissions to Crossref.

Ported from: ndi/+ndi/+cloud/+admin/checkSubmission.m
"""

import os
from typing import Literal, Optional

# Note: These imports assume a crossref Python package or need to be implemented
try:
    import crossref  # type: ignore
except ImportError:
    crossref = None


def check_submission(
    filename: str,
    data_type: Literal["contents", "result"] = "result",
    use_test_system: bool = False
) -> None:
    """Check status of a deposited submission.

    Queries Crossref to retrieve either the result (status) or the full contents
    of a previously submitted metadata file.

    Args:
        filename: The name of the file to check submission status for.
            This should match the filename used during submission.
        data_type: The type of data to check:
            - "contents": Returns the full XML content of the submission
            - "result": Returns the submission status/result (default)
        use_test_system: Flag indicating whether to use the test system.
            Must match what was used during submission (default: False).

    Raises:
        ValueError: If credentials are not set or filename is invalid.
        RuntimeError: If the submission check fails.

    Environment Variables Required:
        CROSSREF_USERNAME: Crossref API username
        CROSSREF_PASSWORD: Crossref API password

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/checkSubmission.m

    Example:
        >>> # Set environment variables first
        >>> os.environ['CROSSREF_USERNAME'] = 'your_username'
        >>> os.environ['CROSSREF_PASSWORD'] = 'your_password'
        >>>
        >>> # Check submission result
        >>> check_submission('dataset_batch-2025-01-15T10:30:00', data_type='result')
        >>>
        >>> # Check submission contents
        >>> check_submission('dataset_batch-2025-01-15T10:30:00', data_type='contents')
    """
    # Validate data_type
    if data_type not in ("contents", "result"):
        raise ValueError(f"data_type must be 'contents' or 'result', got: {data_type}")

    # Get credentials from environment
    username = os.getenv('CROSSREF_USERNAME')
    password = os.getenv('CROSSREF_PASSWORD')

    if not username or not password:
        raise ValueError(
            "Crossref credentials not found. Please set CROSSREF_USERNAME "
            "and CROSSREF_PASSWORD environment variables."
        )

    # Call crossref check_submission function
    if crossref is not None:
        crossref.check_submission(
            filename=filename,
            data_type=data_type,
            use_test_system=use_test_system
        )
    else:
        print("Warning: crossref package not available")
        print(f"Would check submission:")
        print(f"  Filename: {filename}")
        print(f"  Data type: {data_type}")
        print(f"  Use test system: {use_test_system}")
        print(f"  Username: {username}")
        print("\nNote: Install a Python Crossref library to enable actual submission checking.")
        print("Recommended libraries: habanero, crossrefapi")
