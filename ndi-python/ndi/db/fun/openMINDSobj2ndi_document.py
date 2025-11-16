"""
Convert openMINDS objects to NDI document objects.

This module provides functionality to convert openMINDS metadata objects to
ndi.document objects for storage in the NDI database.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/openMINDSobj2ndi_document.m
"""

from typing import List, Optional, Union


def openMINDSobj2ndi_document(
    openminds_obj,
    session_id: str,
    dependency_type: str = '',
    dependency_value: str = ''
) -> List:
    """
    Convert openMINDS objects to a set of ndi.document objects.

    Args:
        openminds_obj: A single openMINDS object or cell array/list of openMINDS objects
        session_id: The session ID to associate with the documents
        dependency_type: Optional dependency type ('subject', 'element', 'stimulus')
        dependency_value: Value for the dependency (required if dependency_type is given)

    Returns:
        List of ndi.document objects

    Raises:
        ValueError: If dependency_type is given but dependency_value is empty
        ImportError: If openMINDS library is not available

    Example:
        >>> # Assuming openminds_obj is an openMINDS object
        >>> session_id = session.id()
        >>> docs = openMINDSobj2ndi_document(openminds_obj, session_id)
        >>> # With dependency
        >>> subject_id = subject_doc.id()
        >>> docs = openMINDSobj2ndi_document(species_obj, session_id, 'subject', subject_id)

    Notes:
        - Requires openMINDS Python library (https://github.com/openMetadataInitiative/openMINDS_Python)
        - Creates documents with openminds metadata structure
        - Automatically detects and links dependencies between openMINDS objects
        - Dependency types map to NDI document dependency names:
          - 'subject' -> 'subject_id'
          - 'element' -> 'element_id'
          - 'stimulus' -> 'stimulus_element_id'
    """
    from ndi.document import Document
    from .openMINDSobj2struct import openMINDSobj2struct

    # Validate dependency arguments
    if dependency_type and not dependency_value:
        raise ValueError("DEPENDENCY_VALUE must not be empty if DEPENDENCY_TYPE is given")

    # Ensure openminds_obj is a list
    if not isinstance(openminds_obj, list):
        if hasattr(openminds_obj, '__iter__') and not isinstance(openminds_obj, str):
            openminds_obj = list(openminds_obj)
        else:
            openminds_obj = [openminds_obj]

    # Convert openMINDS objects to structures
    structures = openMINDSobj2struct(openminds_obj)

    # Determine document name and dependency name based on type
    dependency_name = ''
    doc_name = 'openminds'

    if dependency_type:
        dependency_type_lower = dependency_type.lower()
        if dependency_type_lower == 'subject':
            dependency_name = 'subject_id'
            doc_name = 'openminds_subject'
        elif dependency_type_lower == 'element':
            dependency_name = 'element_id'
            doc_name = 'openminds_element'
        elif dependency_type_lower == 'stimulus':
            dependency_name = 'stimulus_element_id'
            doc_name = 'openminds_stimulus'
        else:
            raise ValueError(f"Unknown DEPENDENCY_TYPE: {dependency_type}")

    # Create NDI documents from structures
    docs = []
    for struct in structures:
        # Remove 'complete' field if present
        openminds_struct = {k: v for k, v in struct.items() if k != 'complete'}

        # Extract NDI ID
        ndi_id = openminds_struct.pop('ndi_id', None)

        # Create document
        doc = Document(
            doc_name,
            **{
                'base.id': ndi_id,
                'base.session_id': session_id,
                'openminds': openminds_struct
            }
        )

        # Add dependencies for nested openMINDS objects
        added_dependency = False
        fields = openminds_struct.get('fields', {})
        if isinstance(fields, dict):
            for field_name, field_value in fields.items():
                # Handle cell arrays/lists
                if isinstance(field_value, list):
                    for item in field_value:
                        if isinstance(item, str) and item.startswith('ndi://'):
                            # Extract ID from NDI URI
                            ref_id = item[6:]  # Remove 'ndi://' prefix
                            doc = doc.add_dependency_value_n('openminds', ref_id)
                            added_dependency = True

        # If no dependencies were added, set empty openminds dependency
        if not added_dependency:
            try:
                doc = doc.set_dependency_value('openminds', '')
            except:
                pass  # Ignore if method doesn't exist

        # Add the specified dependency if provided
        if dependency_name and dependency_value:
            doc = doc.set_dependency_value(dependency_name, dependency_value)

        docs.append(doc)

    return docs
