"""
Create an NDI object from an NDI document.

This module provides functionality to instantiate NDI objects from their
corresponding ndi.document representations stored in the database.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/ndi_document2ndi_object.m
"""

from typing import Union


def ndi_document2ndi_object(ndi_document_obj, ndi_session_obj):
    """
    Create an NDI object from an ndi.document object.

    This function reconstructs an NDI object (such as ndi.element, ndi.probe, etc.)
    from its document representation and the associated session.

    Args:
        ndi_document_obj: An ndi.document object or a document ID string
        ndi_session_obj: The ndi.session object the document belongs to

    Returns:
        The reconstructed NDI object

    Raises:
        TypeError: If ndi_document_obj is not a valid document or ID
        ValueError: If document cannot be found or doesn't have required fields
        RuntimeError: If the object class cannot be instantiated

    Example:
        >>> from ndi.session import Session
        >>> session = Session('/path/to/session')
        >>> doc_id = '1234567890abcdef'
        >>> obj = ndi_document2ndi_object(doc_id, session)
        >>> print(type(obj))  # ndi.element, ndi.probe, etc.

    Notes:
        - If ndi_document_obj is a string, it's treated as a document ID
        - Looks for 'document_class.class_name' to determine object type
        - Extracts the parent object string from class name
        - Finds the class constructor in the document properties
        - Instantiates the object using eval() equivalent in Python
    """
    from ndi.document import Document
    from ndi.query import Query
    import importlib

    # If ndi_document_obj is a string (ID), look it up
    if isinstance(ndi_document_obj, str):
        q = Query('base.id', 'exact_string', ndi_document_obj, '')
        docs = ndi_session_obj.database_search(q)

        if not docs:
            raise ValueError(
                f"NDI_DOCUMENT_OBJ must be of type ndi.document or an ID of a valid ndi.document. "
                f"Document with ID '{ndi_document_obj}' not found."
            )

        if isinstance(docs, list):
            if len(docs) != 1:
                raise ValueError(f"Found {len(docs)} documents with ID '{ndi_document_obj}', expected 1")
            ndi_document_obj = docs[0]
        else:
            ndi_document_obj = docs

    # Validate it's a document
    if not isinstance(ndi_document_obj, Document):
        raise TypeError("ndi_document_obj must be an ndi.document object")

    # Get the class name from document properties
    try:
        classname = ndi_document_obj.document_properties['document_class']['class_name']
    except KeyError:
        raise ValueError("Document does not have 'document_class.class_name' field")

    # Extract object parent string
    doc_string = 'ndi_document_'
    if doc_string in classname:
        index = classname.find(doc_string)
        obj_parent_string = classname[index + len(doc_string):]
    else:
        obj_parent_string = classname

    # Check if the document has the corresponding field
    if obj_parent_string not in ndi_document_obj.document_properties:
        raise ValueError(
            f"NDI_DOCUMENT_OBJ does not have a '{obj_parent_string}' field"
        )

    # Get the object structure and class string
    obj_struct = ndi_document_obj.document_properties[obj_parent_string]
    class_field_name = f'ndi_{obj_parent_string}_class'

    if class_field_name not in obj_struct:
        raise ValueError(
            f"Document field '{obj_parent_string}' does not have '{class_field_name}' field"
        )

    obj_string = obj_struct[class_field_name]

    # Parse the class string (e.g., 'ndi.element.timeseries')
    # and instantiate the object
    try:
        # Split module and class
        parts = obj_string.rsplit('.', 1)
        if len(parts) == 2:
            module_name, class_name = parts
        else:
            module_name = 'ndi'
            class_name = parts[0]

        # Import the module
        try:
            module = importlib.import_module(module_name)
        except ImportError:
            # Try alternative import paths
            try:
                module = importlib.import_module(f'ndi.{module_name}')
            except ImportError:
                raise RuntimeError(f"Could not import module '{module_name}'")

        # Get the class
        if hasattr(module, class_name):
            obj_class = getattr(module, class_name)
        else:
            raise RuntimeError(f"Module '{module_name}' does not have class '{class_name}'")

        # Instantiate the object
        # Most NDI objects have constructor(session, document)
        obj = obj_class(ndi_session_obj, ndi_document_obj)

        return obj

    except Exception as e:
        raise RuntimeError(
            f"Failed to instantiate object of class '{obj_string}': {str(e)}"
        ) from e
