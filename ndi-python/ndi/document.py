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

    def add_dependency_value_n(
        self,
        dependency_name: str,
        value: str,
        error_if_not_found: bool = True
    ) -> 'Document':
        """
        Add a dependency to a named list.

        MATLAB equivalent: ndi.document.add_dependency_value_n()

        Examines the 'depends_on' field and adds a dependency name
        'dependency_name_(n+1)', where n is the number of entries with
        the form 'dependency_name_i' that exist presently.

        Args:
            dependency_name: Base name of the dependency
            value: Value to set for the new dependency
            error_if_not_found: If True, generate error if no dependencies exist

        Returns:
            Document: Self for chaining

        Raises:
            KeyError: If document has no dependencies and error_if_not_found=True

        Example:
            >>> doc.add_dependency_value_n('probe', 'probe_001')
            >>> doc.add_dependency_value_n('probe', 'probe_002')
            # Creates 'probe_1' and 'probe_2'
        """
        d = self.dependency_value_n(dependency_name, error_if_not_found=False)
        has_dependencies = 'depends_on' in self.document_properties

        if not has_dependencies and error_if_not_found:
            raise KeyError("This document does not have any dependencies")

        # Create new dependency name with incremented number
        new_name = f"{dependency_name}_{len(d) + 1}"
        return self.set_dependency_value(new_name, value, error_if_not_found=False)

    def dependency_value_n(
        self,
        dependency_name: str,
        error_if_not_found: bool = True
    ) -> List[str]:
        """
        Return dependency values from list given dependency name.

        MATLAB equivalent: ndi.document.dependency_value_n()

        Examines the 'depends_on' field and returns the values associated
        with dependencies named 'dependency_name_i', where i varies from 1
        to the maximum number of such entries.

        Args:
            dependency_name: Base name of the dependency (without _i suffix)
            error_if_not_found: If True, generate error if not found

        Returns:
            List of dependency values (empty list if none found)

        Raises:
            KeyError: If no matching dependencies and error_if_not_found=True

        Example:
            >>> values = doc.dependency_value_n('probe')
            >>> # Returns ['probe_001', 'probe_002', ...] if probe_1, probe_2, etc. exist
        """
        d = []
        not_found = True

        has_dependencies = 'depends_on' in self.document_properties
        if has_dependencies:
            has_dependencies = len(self.document_properties.get('depends_on', [])) >= 1

        if has_dependencies:
            i = 1
            while True:
                search_name = f"{dependency_name}_{i}"
                found = False

                for dep in self.document_properties['depends_on']:
                    if dep['name'].lower() == search_name.lower():
                        not_found = False
                        d.append(dep['value'])
                        found = True
                        break

                if not found:
                    break
                i += 1

        if not_found and error_if_not_found:
            raise KeyError(f"Dependency name '{dependency_name}' not found")

        return d

    def remove_dependency_value_n(
        self,
        dependency_name: str,
        value: str,
        n: int,
        error_if_not_found: bool = True
    ) -> 'Document':
        """
        Remove a dependency from a named list.

        MATLAB equivalent: ndi.document.remove_dependency_value_n()

        Examines the 'depends_on' field and removes the dependency named
        'dependency_name_n', then renumbers subsequent dependencies.

        Args:
            dependency_name: Base name of the dependency
            value: Value of the dependency (not currently used)
            n: Index number to remove
            error_if_not_found: If True, generate error if not found

        Returns:
            Document: Self for chaining

        Raises:
            KeyError: If dependencies don't exist and error_if_not_found=True
            ValueError: If n > number of entries

        Example:
            >>> doc.remove_dependency_value_n('probe', '', 2)
            # Removes probe_2, renumbers probe_3 to probe_2, etc.
        """
        d = self.dependency_value_n(dependency_name, error_if_not_found=False)
        has_dependencies = 'depends_on' in self.document_properties

        if not has_dependencies and error_if_not_found:
            raise KeyError("This document does not have any dependencies")

        if n > len(d) and error_if_not_found:
            raise ValueError(
                f"Number to be removed {n} is greater than total number of entries {len(d)}"
            )

        # Find and remove the nth entry
        target_name = f"{dependency_name}_{n}"
        match_index = None

        for i, dep in enumerate(self.document_properties['depends_on']):
            if dep['name'].lower() == target_name.lower():
                match_index = i
                break

        if match_index is None:
            raise KeyError(f"Could not locate entry '{target_name}'")

        # Remove the entry
        self.document_properties['depends_on'].pop(match_index)

        # Renumber subsequent entries
        for i in range(n + 1, len(d) + 1):
            old_name = f"{dependency_name}_{i}"
            new_name = f"{dependency_name}_{i - 1}"

            for dep in self.document_properties['depends_on']:
                if dep['name'].lower() == old_name.lower():
                    dep['name'] = new_name
                    break

        return self

    def has_files(self) -> bool:
        """
        Check if document has any files associated with it.

        MATLAB equivalent: ndi.document.has_files()

        Returns:
            bool: True if document has files in file_info

        Example:
            >>> if doc.has_files():
            ...     files = doc.current_file_list()
        """
        return (
            'files' in self.document_properties
            and isinstance(self.document_properties['files'], dict)
            and 'file_info' in self.document_properties['files']
            and len(self.document_properties['files']['file_info']) > 0
        )

    def is_in_file_list(self, name: str) -> Tuple[bool, str, Optional[int], str]:
        """
        Check if a file name is in the document's file list.

        MATLAB equivalent: ndi.document.is_in_file_list()

        A name is valid if it appears in document_properties.files.file_list
        or if it is a numbered file with an entry like 'filename.ext_#'.

        Args:
            name: File name to check

        Returns:
            Tuple of (is_valid, error_message, file_info_index, file_uid)
            - is_valid: True if name is valid
            - error_message: Reason if not valid (empty if valid)
            - file_info_index: Index in file_info array (None if not found)
            - file_uid: File UID if found (empty string otherwise)

        Example:
            >>> valid, msg, idx, uid = doc.is_in_file_list('data.bin')
            >>> if valid:
            ...     print(f"File at index {idx} with UID {uid}")
        """
        b = True
        msg = ''
        fI_index = None
        fuid = ''

        # Step 1: Does this document have 'files' at all?
        if 'files' not in self.document_properties:
            return False, "This type of document does not accept files; it has no 'files' field", None, ''

        # Step 2: Check if it's a valid filename
        # Step 2a: See if name ends in '_#' (numbered file)
        search_name = name
        ends_with_number = False
        number = None

        underscores = [i for i, c in enumerate(name) if c == '_']
        if underscores:
            try:
                number = int(name[underscores[-1] + 1:])
                ends_with_number = True
                search_name = name[:underscores[-1] + 1] + '#'
            except ValueError:
                pass

        # Step 2b: Check if search_name is in file_list
        file_list = self.document_properties['files'].get('file_list', [])
        found = any(search_name.lower() == f.lower() for f in file_list)

        if not found:
            return False, f"No such file '{name}' in file_list of document; file must match an expected name", None, ''

        # Step 3: Find which file_info corresponds to search_name
        if 'file_info' in self.document_properties['files']:
            for i, finfo in enumerate(self.document_properties['files']['file_info']):
                if finfo['name'].lower() == name.lower():
                    fI_index = i
                    if 'locations' in finfo and len(finfo['locations']) > 0:
                        fuid = finfo['locations'][0].get('uid', '')
                    break

        return b, msg, fI_index, fuid

    def get_fuid(self, filename: str) -> str:
        """
        Return the file UID for a given filename.

        MATLAB equivalent: ndi.document.get_fuid()

        Args:
            filename: File name to look up

        Returns:
            str: File UID if found, empty string otherwise

        Example:
            >>> fuid = doc.get_fuid('data.bin')
        """
        _, _, _, fuid = self.is_in_file_list(filename)
        return fuid

    def current_file_list(self) -> List[str]:
        """
        Return the list of files that have been associated with the document.

        MATLAB equivalent: ndi.document.current_file_list()

        This is a subset of all possible files (in file_list) and includes
        only files that have actually been added (in file_info).

        Returns:
            List[str]: List of file names

        Example:
            >>> files = doc.current_file_list()
            >>> for f in files:
            ...     print(f"Document has file: {f}")
        """
        if 'files' not in self.document_properties:
            return []

        if 'file_info' not in self.document_properties['files']:
            return []

        return [finfo['name'] for finfo in self.document_properties['files']['file_info']]

    def remove_file(
        self,
        name: str,
        location: Optional[str] = None,
        error_if_no_file_info: bool = False
    ) -> 'Document':
        """
        Remove file information from the document.

        MATLAB equivalent: ndi.document.remove_file()

        If location is not specified or is empty, all locations are removed.

        Args:
            name: File name to remove
            location: Specific location to remove (or None to remove all)
            error_if_no_file_info: If True, raise error if file_info is empty

        Returns:
            Document: Self for chaining

        Raises:
            ValueError: If name is not in file_list
            KeyError: If file_info is empty and error_if_no_file_info=True

        Example:
            >>> doc.remove_file('data.bin')  # Remove all locations
            >>> doc.remove_file('data.bin', '/path/to/file')  # Remove specific location
        """
        b, msg, fI_index = self.is_in_file_list(name)[:3]

        if not b:
            raise ValueError(msg)

        if fI_index is None:
            if error_if_no_file_info:
                raise KeyError(f"No file_info for name '{name}'")
            return self

        # Remove all locations if location not specified
        if location is None or location == '':
            self.document_properties['files']['file_info'].pop(fI_index)
            return self

        # Remove specific location
        file_info = self.document_properties['files']['file_info'][fI_index]
        location_match_index = None

        for i, loc in enumerate(file_info.get('locations', [])):
            if loc.get('location', '').lower() == location.lower():
                location_match_index = i
                break

        if location_match_index is None:
            if error_if_no_file_info:
                raise KeyError(f"No match found for file '{name}' with location '{location}'")
        else:
            file_info['locations'].pop(location_match_index)

        return self

    def reset_file_info(self) -> 'Document':
        """
        Reset (make empty) all file info structures for the document.

        MATLAB equivalent: ndi.document.reset_file_info()

        Sets document_properties.files.file_info to an empty list.

        Returns:
            Document: Self for chaining

        Example:
            >>> doc.reset_file_info()  # Clear all file associations
        """
        if 'files' not in self.document_properties:
            return self

        self.document_properties['files']['file_info'] = []
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

    def setproperties(self, **properties) -> 'Document':
        """
        Set property values of the document.

        MATLAB equivalent: ndi.document.setproperties()

        Property values should be expressed relative to document_properties
        using dot notation (e.g., 'base.name').

        Args:
            **properties: Property paths and values to set

        Returns:
            Document: Self for chaining

        Raises:
            ValueError: If property path is invalid

        Example:
            >>> doc.setproperties(**{'base.name': 'my document'})
            >>> # Alternative using literal syntax:
            >>> doc.setproperties(base_name='my value')  # Sets 'base.name'
        """
        for property_path, value in properties.items():
            # Convert underscore notation to dot notation if needed
            if '.' not in property_path and '_' in property_path:
                # This allows base_name to become base.name
                parts = property_path.split('_', 1)
                property_path = '.'.join(parts)

            try:
                self._set_nested_property(property_path, value)
            except Exception as e:
                raise ValueError(f"Error in assigning '{property_path}': {e}") from e

        return self

    def validate(self) -> bool:
        """
        Evaluate whether document is valid by its schema.

        MATLAB equivalent: ndi.document.validate()

        Checks the fields of the document against the schema in
        document_properties.validation_schema.

        Returns:
            bool: True if valid (currently always True - validation not implemented)

        Example:
            >>> if doc.validate():
            ...     session.database_add(doc)
        """
        # For now, skip validation - matches MATLAB behavior
        # Full implementation would validate against JSON schema
        return True

    def to_table(self):
        """
        Convert document to a pandas DataFrame table.

        MATLAB equivalent: ndi.document.to_table()

        Field names are converted to table column names. Substructures
        use dot notation for column names.

        'depends_on' elements are given names like 'depends_on_NAME'.

        Returns:
            pandas.DataFrame: Document as a table with one row

        Raises:
            ImportError: If pandas is not installed

        Example:
            >>> df = doc.to_table()
            >>> print(df.columns)
        """
        try:
            import pandas as pd
        except ImportError:
            raise ImportError("pandas is required for to_table(). Install with: pip install pandas")

        # Start with dependencies
        data = {}
        names, depend_struct = self.dependency()
        for i, dep in enumerate(depend_struct):
            col_name = f"depends_on_{dep['name']}"
            data[col_name] = [dep['value']]

        # Flatten the document properties (excluding depends_on and files)
        s = self.document_properties.copy()
        if 'depends_on' in s:
            del s['depends_on']
        if 'files' in s:
            del s['files']

        # Flatten nested structure
        flat_data = self._flatten_dict(s)

        # Add to data dictionary
        for key, value in flat_data.items():
            data[key] = [value]

        return pd.DataFrame(data)

    def _flatten_dict(self, d: Dict, parent_key: str = '', sep: str = '.') -> Dict:
        """
        Flatten a nested dictionary.

        Args:
            d: Dictionary to flatten
            parent_key: Parent key for recursion
            sep: Separator for nested keys

        Returns:
            Dict: Flattened dictionary
        """
        items = []
        for k, v in d.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(self._flatten_dict(v, new_key, sep=sep).items())
            elif isinstance(v, list):
                # Convert lists to strings for table representation
                items.append((new_key, str(v)))
            else:
                items.append((new_key, v))
        return dict(items)

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

    @staticmethod
    def find_doc_by_id(doc_array: List['Document'], doc_id: str) -> Tuple[Optional['Document'], Optional[int]]:
        """
        Find a document in an array by ID.

        MATLAB equivalent: ndi.document.find_doc_by_id()

        Args:
            doc_array: List of Document objects to search
            doc_id: Document ID to search for

        Returns:
            Tuple of (document, index) or (None, None) if not found

        Example:
            >>> docs = [doc1, doc2, doc3]
            >>> found_doc, idx = Document.find_doc_by_id(docs, 'abc123')
            >>> if found_doc:
            ...     print(f"Found at index {idx}")
        """
        for i, doc in enumerate(doc_array):
            if doc.id() == doc_id:
                return doc, i

        return None, None

    @staticmethod
    def find_newest(doc_array: List['Document']) -> Tuple[Optional['Document'], Optional[int], List[datetime]]:
        """
        Find the newest document in an array.

        MATLAB equivalent: ndi.document.find_newest()

        Args:
            doc_array: List of Document objects to search

        Returns:
            Tuple of (newest_document, index, all_timestamps)
            - newest_document: The newest document
            - index: Index of newest document
            - all_timestamps: List of datetime objects for all documents

        Raises:
            ValueError: If doc_array is empty

        Example:
            >>> docs = [doc1, doc2, doc3]
            >>> newest, idx, timestamps = Document.find_newest(docs)
            >>> print(f"Newest document created at {timestamps[idx]}")
        """
        if not doc_array:
            raise ValueError("Cannot find newest document in empty array")

        timestamps = []
        for doc in doc_array:
            datestamp = doc.document_properties['base']['datestamp']
            # Parse ISO format timestamp
            # Handle both 'Z' suffix and +00:00 suffix
            if datestamp.endswith('Z'):
                datestamp = datestamp[:-1] + '+00:00'
            try:
                dt = datetime.fromisoformat(datestamp)
            except:
                # Fallback for older datetime formats
                from dateutil import parser
                dt = parser.parse(datestamp)
            timestamps.append(dt)

        # Find index of newest (maximum timestamp)
        newest_index = timestamps.index(max(timestamps))
        newest_doc = doc_array[newest_index]

        return newest_doc, newest_index, timestamps

    def __repr__(self) -> str:
        """String representation."""
        doc_id = self.id()[:8] if self.id() else 'None'
        doc_class = self.doc_class() if 'document_class' in self.document_properties else 'Unknown'
        return f"Document(id='{doc_id}...', class='{doc_class}')"
