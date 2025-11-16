"""
NDI AppDoc - Mixin for apps that manage parameter documents.

This module provides a mixin class for NDI apps that create and manage
parameter documents in the database.
"""

from typing import List, Optional, Any, Dict


class AppDoc:
    """
    Mixin class for apps that manage parameter documents.

    This class provides functionality for apps to create, find, and manage
    documents that contain app parameters and results.

    Attributes:
        doc_types: List of internal names for document types
        doc_document_types: List of NDI document datatypes
        doc_session: Session object for database access

    Examples:
        >>> class MyApp(AppDoc):
        ...     def __init__(self, session):
        ...         super().__init__(['my_doc'], ['my_doc_type'], session)
    """

    def __init__(self, doc_types: List[str], doc_document_types: List[str],
                 doc_session: Optional[Any] = None):
        """
        Initialize an AppDoc object.

        Args:
            doc_types: List of internal names for document types
            doc_document_types: List of NDI document datatypes
            doc_session: Session object for database access

        Examples:
            >>> appdoc = AppDoc(['extraction'], ['spike_extraction_parameters'], session)
        """
        self.doc_types = doc_types
        self.doc_document_types = doc_document_types
        self.doc_session = doc_session

    def defaultstruct_appdoc(self, appdoc_type: str) -> Dict[str, Any]:
        """
        Return a default appdoc structure for a given appdoc type.

        Args:
            appdoc_type: The type of appdoc to get default structure for

        Returns:
            Dictionary containing default structure

        Raises:
            ValueError: If appdoc_type is unknown

        Examples:
            >>> appdoc = AppDoc(['my_type'], ['my_doc_type'], session)
            >>> struct = appdoc.defaultstruct_appdoc('my_type')
        """
        try:
            ind = self.doc_types.index(appdoc_type)
        except ValueError:
            raise ValueError(f'Unknown APPDOC_TYPE: {appdoc_type}')

        from .document import Document
        appdoc_doc = Document(self.doc_document_types[ind])
        return self.doc2struct(appdoc_type, appdoc_doc)

    def doc2struct(self, appdoc_type: str, doc: Any) -> Dict[str, Any]:
        """
        Convert an ndi.document to a data structure.

        Args:
            appdoc_type: The type of appdoc
            doc: The ndi.document to convert

        Returns:
            Dictionary containing document data

        Examples:
            >>> struct = appdoc.doc2struct('my_type', my_doc)
        """
        # Get the property list name from document
        listname = doc.document_properties.document_class.property_list_name
        return getattr(doc.document_properties, listname, {})

    def struct2doc(self, appdoc_type: str, appdoc_struct: Dict[str, Any],
                   *args, **kwargs) -> Optional[Any]:
        """
        Create an ndi.document from a data structure.

        Args:
            appdoc_type: The type of appdoc
            appdoc_struct: Data structure containing document properties
            *args: Additional positional arguments
            **kwargs: Additional keyword arguments

        Returns:
            ndi.document object or None

        Examples:
            >>> doc = appdoc.struct2doc('my_type', {'param': 'value'})
        """
        # Base class implementation - should be overridden in subclasses
        return None

    def find_appdoc(self, appdoc_type: str, *args, **kwargs) -> List[Any]:
        """
        Find app documents of a given type in the database.

        Args:
            appdoc_type: The type of appdoc to find
            *args: Additional search criteria
            **kwargs: Additional search parameters

        Returns:
            List of matching documents

        Examples:
            >>> docs = appdoc.find_appdoc('my_type')
        """
        # Base class implementation - should be overridden in subclasses
        return []

    def isequal_appdoc_struct(self, appdoc_type: str, struct1: Dict[str, Any],
                              struct2: Dict[str, Any]) -> bool:
        """
        Compare two appdoc structures for equality.

        Args:
            appdoc_type: The type of appdoc
            struct1: First structure to compare
            struct2: Second structure to compare

        Returns:
            True if structures are equal, False otherwise

        Examples:
            >>> equal = appdoc.isequal_appdoc_struct('my_type', struct1, struct2)
        """
        # Simple equality check - can be overridden in subclasses
        return struct1 == struct2

    def appdoc_description(self, appdoc_type: str) -> str:
        """
        Return documentation for the appdoc type.

        Args:
            appdoc_type: The type of appdoc

        Returns:
            Documentation string

        Examples:
            >>> desc = appdoc.appdoc_description('my_type')
        """
        # Base class implementation - should be overridden in subclasses
        return f'Documentation for {appdoc_type}'
