"""
Mock Database - A simple in-memory database for testing.

This module provides a mock database implementation that stores documents
in memory, useful for testing without file I/O.
"""

from typing import List, Dict, Any, Optional
from ..document import Document
from ..query import Query


class MockDatabase:
    """
    Mock in-memory database for testing.

    Stores documents in a simple dict, allowing testing of NDI functionality
    without requiring file system operations.

    Example:
        >>> from ndi.mock.database import MockDatabase
        >>> db = MockDatabase()
        >>> doc = Document('base')
        >>> db.add(doc)
        >>> results = db.search(Query('', 'isa', 'base'))
        >>> len(results)
        1
    """

    def __init__(self):
        """Create a new mock database."""
        self.documents: Dict[str, Document] = {}

    def add(self, document: Document) -> None:
        """
        Add a document to the database.

        Args:
            document: Document to add

        Example:
            >>> db = MockDatabase()
            >>> doc = Document('base')
            >>> db.add(doc)
        """
        doc_id = document.id()
        self.documents[doc_id] = document

    def read(self, doc_id: str) -> Optional[Document]:
        """
        Read a document by ID.

        Args:
            doc_id: Document ID to read

        Returns:
            Document if found, None otherwise

        Example:
            >>> db = MockDatabase()
            >>> doc = Document('base')
            >>> db.add(doc)
            >>> retrieved = db.read(doc.id())
            >>> retrieved is not None
            True
        """
        return self.documents.get(doc_id)

    def search(self, query: Query) -> List[Document]:
        """
        Search for documents matching a query.

        Args:
            query: Query object

        Returns:
            List of matching documents

        Note:
            This is a simplified search that may not support all query types.

        Example:
            >>> db = MockDatabase()
            >>> doc = Document('base')
            >>> db.add(doc)
            >>> results = db.search(Query('', 'isa', 'base'))
            >>> len(results) > 0
            True
        """
        results = []

        for doc in self.documents.values():
            # Simplified query matching - just check document type
            if self._matches_query(doc, query):
                results.append(doc)

        return results

    def _matches_query(self, doc: Document, query: Query) -> bool:
        """
        Check if a document matches a query (simplified).

        Args:
            doc: Document to check
            query: Query to match

        Returns:
            True if document matches query
        """
        # For mock, just use the query's built-in matches method
        return query.matches(doc)

    def remove(self, doc_or_id) -> None:
        """
        Remove a document from the database.

        Args:
            doc_or_id: Document or document ID to remove

        Example:
            >>> db = MockDatabase()
            >>> doc = Document('base')
            >>> db.add(doc)
            >>> db.remove(doc)
            >>> db.read(doc.id()) is None
            True
        """
        if isinstance(doc_or_id, str):
            doc_id = doc_or_id
        else:
            doc_id = doc_or_id.id()

        if doc_id in self.documents:
            del self.documents[doc_id]

    def clear(self) -> None:
        """
        Clear all documents from the database.

        Example:
            >>> db = MockDatabase()
            >>> doc = Document('base')
            >>> db.add(doc)
            >>> db.clear()
            >>> len(db.documents)
            0
        """
        self.documents.clear()

    def __len__(self) -> int:
        """Return number of documents in database."""
        return len(self.documents)

    def __repr__(self) -> str:
        """String representation."""
        return f"MockDatabase(documents={len(self.documents)})"
