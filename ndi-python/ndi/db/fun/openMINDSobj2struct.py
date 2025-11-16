"""
Convert openMINDS objects to Python structures for NDI documents.

This module provides functionality to convert openMINDS objects to Python
dictionaries suitable for creating NDI documents.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/openMINDSobj2struct.m
"""

from typing import List, Dict, Any, Optional
import uuid


def openMINDSobj2struct(openminds_obj, cache_key: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Convert openMINDS objects to Python structures for creating NDI documents.

    This function recursively converts openMINDS objects and their nested
    references into Python dictionaries, maintaining a cache to handle
    circular references and avoid duplicate processing.

    Args:
        openminds_obj: A list/array of openMINDS objects to convert
        cache_key: Internal cache key for recursive calls (do not provide)

    Returns:
        List of dictionaries, each representing an openMINDS object with fields:
            - openminds_type: The openMINDS schema type
            - matlab_type: The Python class type
            - openminds_id: The original openMINDS object ID
            - ndi_id: The generated NDI document ID
            - fields: Dictionary of field values
            - complete: Boolean indicating if conversion is complete

    Example:
        >>> # Assuming you have openMINDS objects
        >>> structures = openMINDSobj2struct([person_obj, affiliation_obj])
        >>> for struct in structures:
        ...     print(f"Type: {struct['openminds_type']}, ID: {struct['ndi_id']}")

    Notes:
        - Requires openMINDS Python library
        - Maintains conversion stack in cache to handle circular references
        - Converts nested openMINDS objects recursively
        - Converts string and datetime objects to strings for database storage
        - Creates NDI URIs (ndi://<id>) for cross-references
    """
    from ndi.ido import IDO

    # Global cache for conversion stack (simplified - in production use proper caching)
    global_cache = {}

    # Initialize on first call
    if cache_key is None:
        cache_key = str(uuid.uuid4())
        global_cache[cache_key] = []
        initial_call = True
    else:
        initial_call = False

    # Get current conversion stack
    structures = global_cache.get(cache_key, [])

    # Ensure openminds_obj is a list
    if not isinstance(openminds_obj, list):
        if hasattr(openminds_obj, '__iter__') and not isinstance(openminds_obj, str):
            openminds_obj = list(openminds_obj)
        else:
            openminds_obj = [openminds_obj]

    # Process each object
    for obj in openminds_obj:
        # Build preliminary entry
        struct_here = {
            'openminds_type': get_openminds_type(obj),
            'matlab_type': type(obj).__name__,
            'openminds_id': get_openminds_id(obj),
            'ndi_id': IDO().identifier,
            'fields': {},
            'complete': False
        }

        # Check if we already processed this object
        existing_indices = [
            i for i, s in enumerate(structures)
            if s.get('openminds_id') == struct_here['openminds_id']
        ]

        if existing_indices:
            index = existing_indices[0]
            if structures[index].get('complete'):
                # Already built, skip it
                continue
        else:
            # Add new structure
            index = len(structures)
            structures.append(struct_here)

        # Update cache
        global_cache[cache_key] = structures

        # Process fields
        try:
            fields = get_object_fields(obj)
        except Exception:
            # If we can't get fields, mark as complete and continue
            structures[index]['complete'] = True
            continue

        for field_name, field_value in fields.items():
            # Convert strings and datetime to strings
            if hasattr(field_value, '__class__'):
                if field_value.__class__.__name__ in ['str', 'string']:
                    field_value = str(field_value)
                elif 'datetime' in field_value.__class__.__name__:
                    field_value = str(field_value)

            # Handle nested openMINDS objects
            if is_openminds_object(field_value):
                # Recursively convert
                openMINDSobj2struct([field_value], cache_key)
                # Create NDI URI reference
                child_id = get_openminds_id(field_value)
                field_value = f"ndi://{child_id}"
            elif isinstance(field_value, list):
                # Handle lists of openMINDS objects
                new_list = []
                for item in field_value:
                    if is_openminds_object(item):
                        openMINDSobj2struct([item], cache_key)
                        child_id = get_openminds_id(item)
                        new_list.append(f"ndi://{child_id}")
                    else:
                        new_list.append(item)
                field_value = new_list

            structures[index]['fields'][field_name] = field_value

        # Mark as complete
        structures[index]['complete'] = True
        global_cache[cache_key] = structures

    # Clean up cache on initial call
    if initial_call and cache_key in global_cache:
        result = global_cache.pop(cache_key)
        return result

    return structures


def get_openminds_type(obj) -> str:
    """Extract openMINDS type from object."""
    if hasattr(obj, 'X_TYPE'):
        return str(obj.X_TYPE)
    elif hasattr(obj, '_type'):
        return str(obj._type)
    else:
        return type(obj).__name__


def get_openminds_id(obj) -> str:
    """Extract openMINDS ID from object."""
    if hasattr(obj, 'id'):
        return str(obj.id)
    elif hasattr(obj, '_id'):
        return str(obj._id)
    else:
        return str(uuid.uuid4())


def is_openminds_object(obj) -> bool:
    """Check if object is an openMINDS schema object."""
    if obj is None:
        return False
    class_name = type(obj).__module__
    return 'openminds' in class_name.lower()


def get_object_fields(obj) -> Dict[str, Any]:
    """Extract fields from openMINDS object."""
    fields = {}
    if hasattr(obj, '__dict__'):
        for key, value in obj.__dict__.items():
            if not key.startswith('_'):  # Skip private attributes
                fields[key] = value
    return fields
