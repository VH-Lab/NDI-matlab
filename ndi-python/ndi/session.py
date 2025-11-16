"""
NDI Session - Central hub for managing neuroscience experiments.
"""

from typing import List, Optional, Union
from pathlib import Path
from .ido import IDO
from .database import Database, DirectoryDatabase
from .document import Document
from .query import Query
from .cache import Cache
from .documentservice import DocumentService


class Session(DocumentService):
    """
    NDI Session - manages an experimental session.

    A session is the central context for NDI, containing:
    - A database of documents
    - DAQ systems
    - Probes and elements
    - Time synchronization graph
    - Cache for performance
    """

    def __init__(self, reference: str):
        """
        Create a new session (abstract - use subclass like session.dir).

        Args:
            reference: String reference for the session
        """
        self.reference = reference
        ido = IDO()
        self.identifier = ido.id()
        self.database: Optional[Database] = None
        self.cache = Cache()
        self.syncgraph = None  # Will be ndi.time.syncgraph
        self._autoclose_listeners = {}

    def id(self) -> str:
        """
        Get the session's unique identifier.

        Returns:
            str: Session ID
        """
        return self.identifier

    def newdocument(self, document_type: str = 'base', **properties) -> Document:
        """
        Create a new document for this session.

        Args:
            document_type: Type of document
            **properties: Properties to set

        Returns:
            Document: New document with session ID set
        """
        properties['base.session_id'] = self.id()
        return Document(document_type, **properties)

    def searchquery(self) -> Query:
        """
        Get a search query that matches all documents in this session.

        Returns:
            Query: Query for this session
        """
        return Query('base.session_id', 'exact_string', self.id())

    def database_add(self, document: Union[Document, List[Document]]) -> 'Session':
        """
        Add document(s) to the session database.

        Args:
            document: Document or list of documents

        Returns:
            Session: Self for chaining
        """
        if not isinstance(document, list):
            document = [document]

        # Validate and set session IDs
        for doc in document:
            current_session_id = doc.session_id()
            if current_session_id and current_session_id != self.id():
                raise ValueError(
                    f"Document {doc.id()} has session_id {current_session_id} "
                    f"which doesn't match {self.id()}"
                )
            if not current_session_id:
                doc.set_session_id(self.id())

        self.database.add(document)
        return self

    def database_search(self, query: Query) -> List[Document]:
        """
        Search for documents in the session database.

        Args:
            query: Query object

        Returns:
            List[Document]: Matching documents
        """
        # Always filter by session ID
        session_query = self.searchquery()
        combined_query = query & session_query
        return self.database.search(combined_query)

    def database_rm(self, document_or_id: Union[str, Document, List]) -> 'Session':
        """
        Remove document(s) from the database.

        Args:
            document_or_id: Document ID, Document, or list

        Returns:
            Session: Self for chaining
        """
        self.database.remove(document_or_id)
        return self

    def database_clear(self, areyousure: str = 'no') -> None:
        """
        Clear all documents from the session database.

        Args:
            areyousure: Must be 'yes' to proceed
        """
        if areyousure.lower() != 'yes':
            print("Not clearing because user did not indicate they are sure.")
            return

        # Get all documents for this session
        all_docs = self.database_search(self.searchquery())
        for doc in all_docs:
            self.database_rm(doc)

    def database_openbinarydoc(
        self,
        document_or_id: Union[str, Document],
        filename: str,
        auto_close: bool = False
    ):
        """
        Open a binary document file.

        Args:
            document_or_id: Document or document ID
            filename: Filename to open
            auto_close: If True, automatically close when object is deleted

        Returns:
            File handle
        """
        handle = self.database.openbinarydoc(document_or_id, filename)

        if auto_close:
            # Store listener for auto-close
            self._autoclose_listeners[id(handle)] = handle

        return handle

    def database_closebinarydoc(self, binarydoc_obj) -> None:
        """
        Close a binary document file.

        Args:
            binarydoc_obj: File handle to close
        """
        self.database.closebinarydoc(binarydoc_obj)

        # Remove from auto-close listeners
        handle_id = id(binarydoc_obj)
        if handle_id in self._autoclose_listeners:
            del self._autoclose_listeners[handle_id]

    def daqsystem_add(self, daq_system) -> 'Session':
        """
        Add a DAQ system to the session.

        Args:
            daq_system: DAQ system object

        Returns:
            Session: Self for chaining
        """
        # Set the session for the DAQ system
        daq_system.set_session(self)

        # Check if already exists
        search_query = daq_system.searchquery()
        existing = self.database_search(search_query)

        if existing:
            raise ValueError(f"DAQ system {daq_system.name} already exists in session")

        # Add to database
        doc = daq_system.newdocument()
        self.database_add(doc)

        return self

    def daqsystem_load(self, **criteria) -> Union[List, object, None]:
        """
        Load DAQ system(s) from the session.

        Args:
            **criteria: Search criteria (e.g., name='my_daq')

        Returns:
            DAQ system object, list of objects, or None
        """
        query = Query('', 'isa', 'daqsystem', '')

        for key, value in criteria.items():
            if key == 'name':
                query = query & Query('base.name', 'exact_string', value)
            else:
                query = query & Query(key, 'exact_string', value)

        docs = self.database_search(query)

        if not docs:
            return None

        # Convert documents to DAQ system objects
        systems = []
        for doc in docs:
            # Would need to instantiate appropriate DAQ system class
            # For now, just return the document
            systems.append(doc)

        if len(systems) == 1:
            return systems[0]
        return systems

    def getprobes(self, **criteria) -> List:
        """
        Get all probes in the session.

        Args:
            **criteria: Filter criteria

        Returns:
            List of probe objects
        """
        query = Query('element.ndi_element_class', 'contains_string', 'probe')

        for key, value in criteria.items():
            query = query & Query(f'element.{key}', 'exact_string', value)

        probe_docs = self.database_search(query)

        # Convert to probe objects (would need full implementation)
        return probe_docs

    def getelements(self, **criteria) -> List:
        """
        Get all elements in the session.

        Args:
            **criteria: Filter criteria

        Returns:
            List of element objects
        """
        query = Query('', 'isa', 'element', '')

        for key, value in criteria.items():
            query = query & Query(f'element.{key}', 'exact_string', value)

        element_docs = self.database_search(query)
        return element_docs

    def __eq__(self, other) -> bool:
        """Check equality based on session ID."""
        if not isinstance(other, Session):
            return False
        return self.id() == other.id()

    @staticmethod
    def empty_id() -> str:
        """
        Return an empty session ID (all zeros).

        Returns:
            str: Empty session ID
        """
        return '0' * 32

    def __repr__(self) -> str:
        """String representation."""
        return f"Session(reference='{self.reference}', id='{self.id()[:8]}...')"


class SessionDir(Session):
    """
    Directory-based session implementation.

    Stores session data in a file system directory.
    """

    def __init__(self, path: str, reference: str):
        """
        Create or open a directory-based session.

        Args:
            path: Directory path for the session
            reference: Session reference name
        """
        super().__init__(reference)

        self.path = Path(path)
        self.path.mkdir(parents=True, exist_ok=True)

        # Initialize database
        self.database = DirectoryDatabase(str(self.path), reference)

    def getpath(self) -> str:
        """
        Get the session directory path.

        Returns:
            str: Directory path
        """
        return str(self.path)

    def __repr__(self) -> str:
        """String representation."""
        return f"SessionDir(path='{self.path}', reference='{self.reference}', id='{self.id()[:8]}...')"
