"""
NDI Document - NoSQL document for storing data and metadata.
"""

import json
import os
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime
from .ido import IDO


class Document:
    """
    NDI Document - unit of storage in the NDI database.

    Documents store both structured metadata and can reference binary data files.
    They support dependencies, inheritance, and flexible schemas.
    """

    def __init__(self, document_type: str = 'base', **properties):
        """
        Create a new document.

        Args:
            document_type: Type of document to create (or dict with document_properties)
            **properties: Property name/value pairs to set
        """
        if isinstance(document_type, dict):
            # Constructing from existing properties
            self.document_properties = document_type
        else:
            # Create from schema
            self.document_properties = self._read_blank_definition(document_type)

            # Set unique ID and timestamp
            ido = IDO()
            self.document_properties['base']['id'] = ido.id()
            self.document_properties['base']['datestamp'] = self._timestamp()

            # Set any provided properties
            for key, value in properties.items():
                self._set_nested_property(key, value)

    @staticmethod
    def _timestamp() -> str:
        """
        Generate an ISO format timestamp.

        Returns:
            str: ISO format timestamp
        """
        return datetime.utcnow().isoformat() + 'Z'

    def _set_nested_property(self, property_path: str, value: Any) -> None:
        """
        Set a nested property using dot notation.

        Args:
            property_path: Property path like 'base.name'
            value: Value to set
        """
        parts = property_path.split('.')
        current = self.document_properties

        for part in parts[:-1]:
            if part not in current:
                current[part] = {}
            current = current[part]

        current[parts[-1]] = value

    def set_session_id(self, session_id: str) -> 'Document':
        """
        Set the session ID for this document.

        Args:
            session_id: Session identifier

        Returns:
            Document: Self for chaining
        """
        self.document_properties['base']['session_id'] = session_id
        return self

    def id(self) -> str:
        """
        Get the document's unique ID.

        Returns:
            str: Document ID
        """
        return self.document_properties['base']['id']

    def session_id(self) -> str:
        """
        Get the document's session ID.

        Returns:
            str: Session ID
        """
        return self.document_properties['base'].get('session_id', '')

    def doc_class(self) -> str:
        """
        Get the document class name.

        Returns:
            str: Document class name
        """
        return self.document_properties['document_class']['class_name']

    def doc_superclass(self) -> List[str]:
        """
        Get the document superclass names.

        Returns:
            List[str]: List of superclass names
        """
        superclasses = []
        if 'superclasses' in self.document_properties['document_class']:
            for sc in self.document_properties['document_class']['superclasses']:
                sc_doc = Document(sc['definition'])
                superclasses.append(sc_doc.doc_class())
        return list(set(superclasses))  # Remove duplicates

    def doc_isa(self, document_class: str) -> bool:
        """
        Check if document is of a given class (including superclasses).

        Args:
            document_class: Class name to check

        Returns:
            bool: True if document is of that class
        """
        if self.doc_class() == document_class:
            return True
        return document_class in self.doc_superclass()

    def dependency(self) -> Tuple[List[str], List[Dict]]:
        """
        Get all dependencies for this document.

        Returns:
            Tuple of (dependency names, dependency structs)
        """
        if 'depends_on' not in self.document_properties:
            return [], []

        depends_on = self.document_properties['depends_on']
        if not depends_on:
            return [], []

        names = [d['name'] for d in depends_on]
        return names, depends_on

    def dependency_value(
        self,
        dependency_name: str,
        error_if_not_found: bool = True
    ) -> Optional[str]:
        """
        Get the value of a dependency by name.

        Args:
            dependency_name: Name of the dependency
            error_if_not_found: Whether to raise error if not found

        Returns:
            str or None: Dependency value

        Raises:
            KeyError: If dependency not found and error_if_not_found=True
        """
        if 'depends_on' not in self.document_properties:
            if error_if_not_found:
                raise KeyError(f"No dependencies in document")
            return None

        for dep in self.document_properties['depends_on']:
            if dep['name'] == dependency_name:
                return dep['value']

        if error_if_not_found:
            raise KeyError(f"Dependency '{dependency_name}' not found")
        return None

    def set_dependency_value(
        self,
        dependency_name: str,
        value: str,
        error_if_not_found: bool = True
    ) -> 'Document':
        """
        Set the value of a dependency.

        Args:
            dependency_name: Name of the dependency
            value: Value to set
            error_if_not_found: If False, adds dependency if not found

        Returns:
            Document: Self for chaining
        """
        if 'depends_on' not in self.document_properties:
            if error_if_not_found:
                raise KeyError("No dependencies in document")
            self.document_properties['depends_on'] = []

        # Find and update existing dependency
        for dep in self.document_properties['depends_on']:
            if dep['name'] == dependency_name:
                dep['value'] = value
                return self

        # Not found
        if error_if_not_found:
            raise KeyError(f"Dependency '{dependency_name}' not found")

        # Add new dependency
        self.document_properties['depends_on'].append({
            'name': dependency_name,
            'value': value
        })

        return self

    def add_file(
        self,
        name: str,
        location: str,
        ingest: Optional[bool] = None,
        delete_original: Optional[bool] = None,
        location_type: Optional[str] = None
    ) -> 'Document':
        """
        Add a file reference to the document.

        Args:
            name: File name for the document
            location: File path or URL
            ingest: Whether to copy file into database
            delete_original: Whether to delete original after ingest
            location_type: 'file', 'url', or 'ndicloud'

        Returns:
            Document: Self for chaining
        """
        # Detect location type if not specified
        if location_type is None:
            if location.startswith(('http://', 'https://')):
                location_type = 'url'
            elif location.startswith('ndic://'):
                location_type = 'ndicloud'
            else:
                location_type = 'file'

        # Set defaults based on location type
        if ingest is None:
            ingest = location_type == 'file'
        if delete_original is None:
            delete_original = location_type == 'file'

        # Create file info structure
        location_info = {
            'location': location.strip(),
            'location_type': location_type,
            'ingest': ingest,
            'delete_original': delete_original,
            'uid': IDO.unique_id(),
            'parameters': ''
        }

        # Initialize files structure if needed
        if 'files' not in self.document_properties:
            self.document_properties['files'] = {
                'file_list': [],
                'file_info': []
            }

        # Check if file already exists
        file_info = self.document_properties['files'].get('file_info', [])
        for finfo in file_info:
            if finfo['name'] == name:
                # Add location to existing file
                finfo['locations'].append(location_info)
                return self

        # Add new file
        self.document_properties['files']['file_info'].append({
            'name': name,
            'locations': [location_info]
        })

        # Add to file list if not already there
        if name not in self.document_properties['files']['file_list']:
            self.document_properties['files']['file_list'].append(name)

        return self

    def __eq__(self, other) -> bool:
        """Check equality based on document ID."""
        if not isinstance(other, Document):
            return False
        return self.id() == other.id()

    def __add__(self, other: 'Document') -> 'Document':
        """
        Merge two documents (plus operator).

        Args:
            other: Document to merge

        Returns:
            Document: Merged document
        """
        # Create a deep copy of self
        import copy
        result = Document(copy.deepcopy(self.document_properties))

        # Merge superclasses
        if 'document_class' in other.document_properties:
            result.document_properties['document_class']['superclasses'].extend(
                other.document_properties['document_class']['superclasses']
            )

        # Merge dependencies
        if 'depends_on' in other.document_properties:
            if 'depends_on' not in result.document_properties:
                result.document_properties['depends_on'] = []
            result.document_properties['depends_on'].extend(
                other.document_properties['depends_on']
            )

        # Merge other fields (simple merge, self takes precedence)
        for key, value in other.document_properties.items():
            if key not in ['document_class', 'depends_on', 'files']:
                if key not in result.document_properties:
                    result.document_properties[key] = value

        return result

    @staticmethod
    def _read_blank_definition(document_type: str) -> Dict:
        """
        Read a blank document definition from JSON schema.

        Args:
            document_type: Type of document

        Returns:
            Dict: Document properties structure
        """
        # This is a simplified version - in full implementation,
        # would read from JSON schema files
        base_structure = {
            'base': {
                'id': '',
                'session_id': '',
                'name': '',
                'datestamp': ''
            },
            'document_class': {
                'definition': f'$NDISCHEMAPATH/{document_type}.json',
                'class_name': document_type,
                'class_version': '1.0',
                'superclasses': []
            }
        }

        return base_structure

    def __repr__(self) -> str:
        """String representation."""
        doc_id = self.id()[:8] if self.id() else 'None'
        doc_class = self.doc_class() if 'document_class' in self.document_properties else 'Unknown'
        return f"Document(id='{doc_id}...', class='{doc_class}')"
