"""Create complete DOI batch submission for Crossref.

This module creates the complete doi_batch structure required for Crossref
metadata submissions, including head, body, and database elements.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/createDoiBatchSubmission.m
"""

from typing import Dict, Any, Optional

from ndi.cloud.admin.crossref.create_database_metadata import create_database_metadata
from ndi.cloud.admin.crossref.create_doi_batch_head_element import (
    create_doi_batch_head_element
)


def create_doi_batch_submission(dataset: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Create a complete DOI batch submission structure.

    This function assembles the complete metadata structure required for
    Crossref DOI registration, including:
    - Head: Administrative information about the submission
    - Body: The actual metadata (database and dataset information)

    Args:
        dataset: Dictionary containing dataset metadata in Crossref format.
            If None or empty, only database metadata is included.

    Returns:
        A dictionary structure representing the complete doi_batch with:
        - head: Administrative metadata
        - body: Content metadata including database and dataset

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/+crossref/createDoiBatchSubmission.m
        The MATLAB version supports a TODO for multiple datasets.

    Example:
        >>> # Create submission for a dataset
        >>> dataset = {'title': 'My Dataset', 'doi': '10.63884/ndic.2025.abc123'}
        >>> doi_batch = create_doi_batch_submission(dataset)
        >>> print(doi_batch.keys())
        dict_keys(['head', 'body'])
    """
    # Create database object
    # TODO: Support multiple datasets?
    database = {
        'database_metadata': create_database_metadata(),
        'dataset': dataset if dataset else None
    }

    # Create body object
    body = {
        'database': database
    }

    # Create doi_batch object
    doi_batch = {
        'head': create_doi_batch_head_element(),
        'body': body
    }

    return doi_batch


# Object-oriented approach (alternative implementation)

class Database:
    """Database element for Crossref submission.

    Attributes:
        database_metadata: Metadata about the NDI Cloud database
        dataset: Individual dataset metadata (optional)
    """

    def __init__(
        self,
        database_metadata: Dict[str, Any],
        dataset: Optional[Dict[str, Any]] = None
    ):
        """Initialize Database.

        Args:
            database_metadata: Database-level metadata
            dataset: Dataset-level metadata (optional)
        """
        self.database_metadata = database_metadata
        self.dataset = dataset

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation.

        Returns:
            Dictionary with database_metadata and dataset
        """
        return {
            'database_metadata': self.database_metadata,
            'dataset': self.dataset
        }


class Body:
    """Body element for DOI batch submission.

    Attributes:
        database: Database object containing database and dataset metadata
    """

    def __init__(self, database: Database):
        """Initialize Body.

        Args:
            database: Database object
        """
        self.database = database

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation.

        Returns:
            Dictionary with database information
        """
        return {
            'database': self.database.to_dict()
        }


class DoiBatch:
    """Complete DOI batch submission structure.

    This represents the top-level element for Crossref metadata submissions.

    Attributes:
        head: Head element with administrative metadata
        body: Body element with content metadata
    """

    def __init__(self, head: Dict[str, Any], body: Body):
        """Initialize DoiBatch.

        Args:
            head: Head element dictionary or object
            body: Body object
        """
        self.head = head
        self.body = body

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation.

        Returns:
            Dictionary with head and body
        """
        return {
            'head': self.head if isinstance(self.head, dict) else self.head.to_dict(),
            'body': self.body.to_dict()
        }

    def to_xml_string(self, output_file: Optional[str] = None) -> str:
        """Generate XML string from DOI batch structure.

        Args:
            output_file: Optional path to save XML file

        Returns:
            XML string representation

        Note:
            This is a placeholder. Actual XML generation would require
            implementing the full Crossref schema.
        """
        # TODO: Implement full XML generation according to Crossref schema
        xml_string = '<?xml version="1.0" encoding="UTF-8"?>\n'
        xml_string += '<doi_batch version="5.3.1" xmlns="http://www.crossref.org/schema/5.3.1">\n'
        xml_string += '  <!-- Head and Body elements would be generated here -->\n'
        xml_string += f'  <!-- {self.to_dict()} -->\n'
        xml_string += '</doi_batch>\n'

        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(xml_string)

        return xml_string


def create_doi_batch_submission_object(
    dataset: Optional[Dict[str, Any]]
) -> DoiBatch:
    """Create a DoiBatch object for submission.

    This is an alternative to create_doi_batch_submission() that returns
    an object instead of a dictionary.

    Args:
        dataset: Dataset metadata dictionary

    Returns:
        DoiBatch object ready for XML generation

    Example:
        >>> dataset = {'title': 'My Dataset'}
        >>> doi_batch = create_doi_batch_submission_object(dataset)
        >>> xml = doi_batch.to_xml_string()
    """
    database = Database(
        database_metadata=create_database_metadata(),
        dataset=dataset
    )

    body = Body(database=database)

    doi_batch = DoiBatch(
        head=create_doi_batch_head_element(),
        body=body
    )

    return doi_batch
