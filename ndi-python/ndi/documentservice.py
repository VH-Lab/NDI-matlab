"""
NDI DocumentService - Mixin for objects that can create and search documents.
"""

from typing import TYPE_CHECKING, Any, Dict, List, Optional

if TYPE_CHECKING:
    from .document import Document
    from .query import Query


class DocumentService:
    """
    Mixin class for objects that provide document services.

    This class provides an interface for creating new documents and
    searching for documents in a database.
    """

    def newdocument(self, document_type: str = 'base', **properties) -> 'Document':
        """
        Create a new document.

        Args:
            document_type: The type of document to create
            **properties: Property name/value pairs to set

        Returns:
            Document: A new document instance
        """
        raise NotImplementedError("Subclasses must implement newdocument()")

    def searchquery(self) -> 'Query':
        """
        Return a search query for documents associated with this object.

        Returns:
            Query: A query object
        """
        raise NotImplementedError("Subclasses must implement searchquery()")
