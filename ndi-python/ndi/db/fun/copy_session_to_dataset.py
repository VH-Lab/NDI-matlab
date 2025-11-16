"""
Copy an ingested NDI session to an NDI dataset.

This module provides functionality to copy all database documents from an
ndi.session object to an ndi.dataset object.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/copy_session_to_dataset.m
"""

from typing import Tuple, List
import warnings


def copy_session_to_dataset(ndi_session_obj, ndi_dataset_obj) -> Tuple[bool, str]:
    """
    Copy an ingested ndi.session object to ndi.dataset object.

    This function copies the database documents of an ndi.session object to an
    ndi.dataset object. The copying process temporarily requires 2 times the
    total disk space occupied by the session, and long-term requires 1 times
    the total disk space (stored in the dataset).

    Args:
        ndi_session_obj: An ndi.session object to copy from
        ndi_dataset_obj: An ndi.dataset object to copy to

    Returns:
        tuple: (success, error_message)
            - success (bool): True if operation succeeds, False otherwise
            - error_message (str): Error description if success is False, empty otherwise

    Example:
        >>> from ndi.session import Session
        >>> from ndi.dataset import Dataset
        >>> session = Session('/path/to/session')
        >>> dataset = Dataset('/path/to/dataset')
        >>> success, errmsg = copy_session_to_dataset(session, dataset)
        >>> if success:
        ...     print("Copy successful")
        ... else:
        ...     print(f"Copy failed: {errmsg}")

    Notes:
        - Checks if session is already part of dataset before copying
        - Extracts all documents and files from session
        - Creates a surrogate session directory in the dataset
        - Sets empty session_id fields to match the current session
    """
    from .extract_docs_files import extract_docs_files

    # Step 1: Check to make sure we haven't previously copied the documents
    try:
        refs, session_ids = ndi_dataset_obj.session_list()
    except AttributeError:
        return False, "ndi_dataset_obj does not appear to be a valid ndi.dataset object"

    if ndi_session_obj.id() in session_ids:
        error_msg = (
            f"Session with ID {ndi_session_obj.id()} "
            f"and reference {ndi_session_obj.reference} "
            f"is already a part of ndi.dataset with ID {ndi_dataset_obj.id()} "
            f"and reference {ndi_dataset_obj.reference}."
        )
        return False, error_msg

    # Step 2: Make a copy of all the documents
    docs, target_path = extract_docs_files(ndi_session_obj)

    # Check for documents with empty session_id and set them
    are_empty_session_id_docs = 0
    for i in range(len(docs)):
        session_id = docs[i].document_properties.get('base', {}).get('session_id', '')
        if not session_id:
            are_empty_session_id_docs += 1
            docs[i] = docs[i].set_session_id(ndi_session_obj.id())

    if are_empty_session_id_docs > 0:
        warnings.warn(
            f"Found {are_empty_session_id_docs} documents with empty session_id. "
            f"Setting them to match the current session."
        )

    # Step 3: Create a surrogate session directory in the dataset
    # Import here to avoid circular imports
    from ndi.session import Session

    try:
        # Get the dataset path
        dataset_path = ndi_dataset_obj.getpath()
    except AttributeError:
        try:
            dataset_path = ndi_dataset_obj.path
        except AttributeError:
            return False, "Could not determine dataset path"

    # Create a surrogate session with the session's reference and ID
    # but located in the dataset directory
    try:
        # Note: This assumes Session has a constructor that accepts reference, path, and session_id
        # The MATLAB version uses ndi.session.dir(reference, path, session_id)
        ndi_session_surrogate = Session(
            reference=ndi_session_obj.reference,
            path=dataset_path,
            session_id=ndi_session_obj.id()
        )
    except Exception as e:
        return False, f"Failed to create surrogate session: {str(e)}"

    # Step 4: Add all documents to the surrogate session
    try:
        ndi_session_surrogate.database_add(docs)
    except Exception as e:
        return False, f"Failed to add documents to surrogate session: {str(e)}"

    # Step 5: Register the session with the dataset
    try:
        ndi_dataset_obj.add_linked_session(ndi_session_surrogate)
    except Exception as e:
        # Even if registration fails, the copy succeeded
        warnings.warn(f"Documents copied but failed to register session with dataset: {str(e)}")

    return True, ""
