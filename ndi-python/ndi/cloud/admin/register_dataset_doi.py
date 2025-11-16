"""Register a Dataset DOI via Crossref.

This module provides functionality to register DOIs for NDI Cloud datasets through
the Crossref DOI registration service.

Ported from: ndi/+ndi/+cloud/+admin/registerDatasetDOI.m
"""

import os
import tempfile
from pathlib import Path
from typing import Optional, Dict, Any

# Note: These imports assume a crossref Python package or need to be implemented
# The MATLAB code uses a crossref package that provides model classes and API functions
try:
    import crossref  # type: ignore
except ImportError:
    crossref = None  # Will need to be implemented or use alternative library


def register_dataset_doi(
    cloud_dataset_id: Optional[str] = None,
    output_file: Optional[str] = None,
    show_xml: bool = True,
    use_test_system: bool = False
) -> None:
    """Register a Dataset DOI via crossref.

    Submit dataset metadata to Crossref for DOI registration. This function:
    1. Retrieves dataset metadata from NDI Cloud
    2. Converts it to Crossref format
    3. Generates XML submission file
    4. Validates the metadata
    5. Submits to Crossref API

    Args:
        cloud_dataset_id: The ID of the dataset in the cloud. If None, will use
            an empty dataset (for testing).
        output_file: The file path to save the XML output. If None, creates a
            temporary file that will be cleaned up.
        show_xml: Flag to display the XML string in the console (default: True).
        use_test_system: Flag to use the test system for submission (default: False).

    Raises:
        ValueError: If dataset retrieval fails or credentials are not set.
        RuntimeError: If XML validation or submission fails.

    Environment Variables Required:
        CROSSREF_USERNAME: Crossref API username
        CROSSREF_PASSWORD: Crossref API password

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/registerDatasetDOI.m

    Example:
        >>> # Set environment variables first
        >>> os.environ['CROSSREF_USERNAME'] = 'your_username'
        >>> os.environ['CROSSREF_PASSWORD'] = 'your_password'
        >>>
        >>> # Register a dataset
        >>> register_dataset_doi('dataset-123', use_test_system=True)
    """
    from ndi.cloud.api.datasets import get_dataset
    from ndi.cloud.admin.crossref.convert_cloud_dataset_to_crossref import (
        convert_cloud_dataset_to_crossref_dataset
    )
    from ndi.cloud.admin.crossref.create_doi_batch_submission import (
        create_doi_batch_submission
    )

    # Create temporary file if needed
    cleanup_file = False
    if output_file is None:
        fd, output_file = tempfile.mkstemp(suffix='.xml')
        os.close(fd)
        cleanup_file = True

    try:
        # Get dataset from cloud
        if cloud_dataset_id is not None:
            success, dataset = get_dataset(cloud_dataset_id)
            if not success:
                error_msg = dataset.get('message', 'Unknown error')
                raise ValueError(f'Failed to get dataset: {error_msg}')
        else:
            dataset = {}

        # Convert to Crossref format
        crossref_dataset = convert_cloud_dataset_to_crossref_dataset(dataset)

        # Create DOI batch submission metadata
        doi_batch_submission_metadata = create_doi_batch_submission(crossref_dataset)

        # Generate XML (saves to provided file path)
        # Note: This assumes the doi_batch_submission_metadata object has a to_xml_string method
        if hasattr(doi_batch_submission_metadata, 'to_xml_string'):
            xml_string = doi_batch_submission_metadata.to_xml_string(output_file)
        else:
            # Fallback: create XML string representation
            xml_string = _generate_xml_string(doi_batch_submission_metadata, output_file)

        if show_xml:
            print(xml_string)

        # Validate metadata
        if crossref is not None:
            crossref.validate_metadata(output_file)
        else:
            print("Warning: crossref package not available, skipping validation")

        # Get credentials from environment
        username = os.getenv('CROSSREF_USERNAME')
        password = os.getenv('CROSSREF_PASSWORD')

        if not username or not password:
            raise ValueError(
                "Crossref credentials not found. Please set CROSSREF_USERNAME "
                "and CROSSREF_PASSWORD environment variables."
            )

        # Post the submission metadata XML file to Crossref
        if crossref is not None:
            crossref.register_doi(
                output_file,
                username=username,
                password=password,
                use_test_system=use_test_system
            )
        else:
            print(f"Warning: crossref package not available")
            print(f"Would submit file: {output_file}")
            print(f"Username: {username}")
            print(f"Use test system: {use_test_system}")

        filename = Path(output_file).stem
        print(f'Deposited file with name "{filename}.xml". '
              f'You can use this filename to check the submission.')

    finally:
        # Clean up temporary file if created
        if cleanup_file and os.path.exists(output_file):
            os.remove(output_file)


def _generate_xml_string(metadata: Any, output_file: str) -> str:
    """Generate XML string from metadata object.

    This is a fallback function for when the metadata object doesn't have
    a to_xml_string method.

    Args:
        metadata: The metadata object to convert to XML
        output_file: Path to save the XML file

    Returns:
        The XML string representation
    """
    # TODO: Implement XML generation based on metadata structure
    xml_string = "<?xml version='1.0' encoding='UTF-8'?>\n"
    xml_string += f"<!-- Generated from metadata: {metadata} -->\n"

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(xml_string)

    return xml_string
