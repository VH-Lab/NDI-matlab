"""Create DOI batch head element for Crossref submission.

This module creates the head element of the doi_batch XML structure required
for Crossref metadata submissions.

Ported from: ndi/+ndi/+cloud/+admin/+crossref/createDoiBatchHeadElement.m
"""

from datetime import datetime
from typing import Dict, Any

from ndi.cloud.admin.crossref.constants import Constants


def create_doi_batch_head_element() -> Dict[str, Any]:
    """Create a structure representing the head element of the doi_batch.

    The head element contains administrative information about the DOI batch
    submission, including:
    - A unique batch identifier
    - A timestamp for versioning
    - Depositor information (name and email)
    - Registrant information (organization)

    Returns:
        A dictionary structure representing the head element with keys:
        - doi_batch_id: Unique identifier for this submission batch
        - timestamp: Integer timestamp for versioning (yyyyMMddHHmmss format)
        - depositor: Dict with depositor_name and email_address
        - registrant: Organization name

    Reference:
        https://data.crossref.org/reports/help/schema_doc/5.3.1/index.html

    Note:
        Ported from MATLAB: ndi/+ndi/+cloud/+admin/+crossref/createDoiBatchHeadElement.m

    Example:
        >>> head = create_doi_batch_head_element()
        >>> print(head['registrant'])
        'Waltham Data Science LLC'
        >>> print(head['depositor']['depositor_name'])
        'Waltham Data Science LLC'
    """
    # Get current timestamp in ISO 8601 format with timezone
    # Format: yyyy-MM-dd'T'HH:mm:ssXXX (e.g., 2025-01-15T10:30:00-05:00)
    timestamp_iso = datetime.now().astimezone().isoformat(timespec='seconds')

    # Publisher generated ID that uniquely identifies the DOI submission batch
    doi_batch_id = f"dataset_batch-{timestamp_iso}"

    # An integer representation of date and time that serves as a version
    # number for the record being deposited, used to uniquely identify
    # batch files and DOI values when a DOI has been updated one or more times
    # Format: yyyyMMddHHmmss
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

    # Depositor information
    # - depositor_name: name of organization
    # - email_address: email address to which batch success and/or error
    #   messages are sent
    depositor = {
        'depositor_name': Constants.DATABASE_ORGANIZATION,
        'email_address': 'steve@walthamdatascience.com'
    }

    # Create head element structure
    head_element = {
        'doi_batch_id': doi_batch_id,
        'timestamp': timestamp,
        'depositor': depositor,
        'registrant': Constants.DATABASE_ORGANIZATION
    }

    return head_element


# Note: The MATLAB version uses crossref.model.Head, crossref.model.Depositor classes
# In Python, we can either:
# 1. Use a similar model class structure if a crossref library is available
# 2. Use dictionaries as shown above
# 3. Create our own model classes

class Depositor:
    """Depositor information for Crossref submission.

    Attributes:
        depositor_name: Name of the organization making the deposit
        email_address: Contact email for submission notifications
    """

    def __init__(self, depositor_name: str, email_address: str):
        """Initialize Depositor.

        Args:
            depositor_name: Name of the organization
            email_address: Contact email address
        """
        self.depositor_name = depositor_name
        self.email_address = email_address

    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary representation.

        Returns:
            Dictionary with depositor_name and email_address
        """
        return {
            'depositor_name': self.depositor_name,
            'email_address': self.email_address
        }


class Head:
    """Head element for DOI batch submission.

    Attributes:
        doi_batch_id: Unique identifier for this submission batch
        timestamp: Timestamp for versioning (yyyyMMddHHmmss)
        depositor: Depositor object with contact information
        registrant: Organization name that owns the DOI prefix
    """

    def __init__(
        self,
        doi_batch_id: str,
        timestamp: str,
        depositor: Depositor,
        registrant: str
    ):
        """Initialize Head element.

        Args:
            doi_batch_id: Unique batch identifier
            timestamp: Version timestamp
            depositor: Depositor information
            registrant: Registrant organization name
        """
        self.doi_batch_id = doi_batch_id
        self.timestamp = timestamp
        self.depositor = depositor
        self.registrant = registrant

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation.

        Returns:
            Dictionary representation of head element
        """
        return {
            'doi_batch_id': self.doi_batch_id,
            'timestamp': self.timestamp,
            'depositor': self.depositor.to_dict(),
            'registrant': self.registrant
        }


def create_doi_batch_head_element_object() -> Head:
    """Create a Head object for DOI batch submission.

    This is an alternative to create_doi_batch_head_element() that returns
    a Head object instead of a dictionary.

    Returns:
        Head object with batch submission metadata

    Example:
        >>> head = create_doi_batch_head_element_object()
        >>> print(head.registrant)
        'Waltham Data Science LLC'
    """
    timestamp_iso = datetime.now().astimezone().isoformat(timespec='seconds')
    doi_batch_id = f"dataset_batch-{timestamp_iso}"
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

    depositor = Depositor(
        depositor_name=Constants.DATABASE_ORGANIZATION,
        email_address='steve@walthamdatascience.com'
    )

    head_element = Head(
        doi_batch_id=doi_batch_id,
        timestamp=timestamp,
        depositor=depositor,
        registrant=Constants.DATABASE_ORGANIZATION
    )

    return head_element
