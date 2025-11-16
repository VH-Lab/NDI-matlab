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

    def daqsystem_rm(self, dev) -> 'Session':
        """
        Remove a DAQ system from the session.

        MATLAB equivalent: ndi.session.daqsystem_rm()

        Args:
            dev: DAQ system object to remove

        Returns:
            Session: Self for chaining

        Raises:
            TypeError: If dev is not a DAQ system
            ValueError: If DAQ system not found

        See Also:
            daqsystem_add, daqsystem_clear
        """
        # Check if it's a DAQ system (duck typing)
        if not hasattr(dev, 'name'):
            raise TypeError("dev must be a ndi.daq.system object")

        # Load the DAQ system by name
        daqsys = self.daqsystem_load(name=dev.name)

        if daqsys is None:
            raise ValueError(f"No DAQ system named '{dev.name}' found")

        # Make list if not already
        if not isinstance(daqsys, list):
            daqsys = [daqsys]

        # Remove each matching DAQ system
        for sys_doc in daqsys:
            # Find the document
            docs = self.database_search(
                Query('base.id', 'exact_string', sys_doc.id())
            )

            for doc in docs:
                # Remove dependencies first
                depends_on = doc.document_properties.get('depends_on', {})
                if isinstance(depends_on, list):
                    for dep in depends_on:
                        if isinstance(dep, dict) and 'value' in dep:
                            dep_docs = self.database_search(
                                Query('base.id', 'exact_string', dep['value'])
                            )
                            self.database_rm(dep_docs)

                # Remove the main document
                self.database_rm(doc)

        return self

    def daqsystem_clear(self) -> 'Session':
        """
        Remove all DAQ systems from the session.

        MATLAB equivalent: ndi.session.daqsystem_clear()

        Permanently removes all ndi.daq.system objects from the session.
        Be sure you mean it!

        Returns:
            Session: Self for chaining

        See Also:
            daqsystem_rm, daqsystem_add
        """
        # Load all DAQ systems (using regex to match any name)
        dev = self.daqsystem_load(name='(.*)')

        if dev is None:
            return self  # No devices to remove

        # Make sure it's a list
        if not isinstance(dev, list):
            dev = [dev]

        # Remove each device
        for d in dev:
            # We need to reconstruct a minimal object with name attribute
            # since daqsystem_rm expects an object with .name
            class DeviceStub:
                def __init__(self, name):
                    self.name = name

            # Extract name from document
            if hasattr(d, 'document_properties'):
                name = d.document_properties.get('base.name', '')
            elif hasattr(d, 'name'):
                name = d.name
            else:
                continue

            stub = DeviceStub(name)
            self.daqsystem_rm(stub)

        return self

    def database_existbinarydoc(
        self,
        document_or_id: Union[str, Document],
        filename: str
    ) -> tuple[bool, str]:
        """
        Check if a binary file exists for a document.

        MATLAB equivalent: ndi.session.database_existbinarydoc()

        Args:
            document_or_id: Document object or document ID
            filename: Binary filename to check

        Returns:
            tuple: (exists: bool, file_path: str)
                   If exists is False, file_path is empty string

        Example:
            >>> exists, path = session.database_existbinarydoc(doc, 'data.bin')
            >>> if exists:
            ...     print(f'Binary file at: {path}')
        """
        # Get document ID
        if isinstance(document_or_id, str):
            doc_id = document_or_id
        else:
            doc_id = document_or_id.id()

        # Check if binary file exists
        if hasattr(self.database, 'get_binary_path'):
            file_path = self.database.get_binary_path(doc_id, filename)
        else:
            # Construct path manually for DirectoryDatabase
            import os
            db_path = getattr(self.database, 'path', '.')
            file_path = os.path.join(db_path, 'binarydocs', doc_id, filename)

        import os
        exists = os.path.isfile(file_path)

        return (exists, file_path if exists else '')

    def syncgraph_addrule(self, rule) -> 'Session':
        """
        Add a synchronization rule to the syncgraph.

        MATLAB equivalent: ndi.session.syncgraph_addrule()

        Args:
            rule: ndi.time.syncrule object

        Returns:
            Session: Self for chaining

        Example:
            >>> from ndi.time.syncrule import SyncRule
            >>> rule = SyncRule(...)
            >>> session.syncgraph_addrule(rule)

        See Also:
            syncgraph_rmrule
        """
        # Initialize syncgraph if needed
        if self.syncgraph is None:
            try:
                from .time.syncgraph import SyncGraph
                self.syncgraph = SyncGraph(self)
            except ImportError:
                # If syncgraph not available, create a simple container
                class SimpleSyncGraph:
                    def __init__(self, session):
                        self.session = session
                        self.rules = []

                    def add_rule(self, rule):
                        self.rules.append(rule)

                    def remove_rule(self, index):
                        if 0 <= index < len(self.rules):
                            del self.rules[index]

                self.syncgraph = SimpleSyncGraph(self)

        # Add the rule
        if hasattr(self.syncgraph, 'add_rule'):
            self.syncgraph.add_rule(rule)
        elif hasattr(self.syncgraph, 'rules'):
            self.syncgraph.rules.append(rule)
        else:
            raise RuntimeError("syncgraph does not support adding rules")

        return self

    def syncgraph_rmrule(self, index: int) -> 'Session':
        """
        Remove a synchronization rule from the syncgraph.

        MATLAB equivalent: ndi.session.syncgraph_rmrule()

        Args:
            index: Index of rule to remove (0-indexed in Python, 1-indexed in MATLAB)

        Returns:
            Session: Self for chaining

        Example:
            >>> session.syncgraph_rmrule(0)  # Remove first rule

        See Also:
            syncgraph_addrule
        """
        if self.syncgraph is None:
            return self  # Nothing to remove

        # Remove the rule
        if hasattr(self.syncgraph, 'remove_rule'):
            self.syncgraph.remove_rule(index)
        elif hasattr(self.syncgraph, 'rules'):
            if 0 <= index < len(self.syncgraph.rules):
                del self.syncgraph.rules[index]
        else:
            raise RuntimeError("syncgraph does not support removing rules")

        return self

    def get_ingested_docs(self) -> List[Document]:
        """
        Get all documents related to ingested data.

        MATLAB equivalent: ndi.session.get_ingested_docs()

        Return all documents related to ingested data. Be careful; if the
        raw data is not available on the path, then the ingested data is
        the only record of it.

        Returns:
            List[Document]: All ingested data documents

        Example:
            >>> ingested = session.get_ingested_docs()
            >>> print(f'Found {len(ingested)} ingested documents')

        See Also:
            ingest, is_fully_ingested
        """
        # Search for all ingested data types (as in MATLAB)
        q_i1 = Query('', 'isa', 'daqreader_mfdaq_epochdata_ingested', '')
        q_i2 = Query('', 'isa', 'daqmetadatareader_epochdata_ingested', '')
        q_i3 = Query('', 'isa', 'epochfiles_ingested', '')
        q_i4 = Query('', 'isa', 'syncrule_mapping', '')

        # Combine with OR
        combined_query = q_i1 | q_i2 | q_i3 | q_i4
        return self.database_search(combined_query)

    def findexpobj(
        self,
        obj_name: str,
        obj_classname: Optional[str] = None
    ) -> Optional[object]:
        """
        Find an experiment object by name and optionally class.

        MATLAB equivalent: ndi.session.findexpobj()

        Searches for objects (probes, elements, DAQ systems) by name
        and optionally by class name.

        Args:
            obj_name: Name of the object to find
            obj_classname: Optional class name filter

        Returns:
            Found object or None if not found

        Example:
            >>> probe = session.findexpobj('electrode1', 'probe')
            >>> element = session.findexpobj('neuron1')
        """
        # Build search query
        query = Query('base.name', 'exact_string', obj_name)

        if obj_classname:
            # Add class filter
            class_query = Query('', 'isa', obj_classname, '')
            query = query & class_query

        # Search
        results = self.database_search(query)

        if not results:
            return None

        # Return first match
        return results[0]

    def creator_args(self) -> dict:
        """
        Return constructor arguments for recreating this session.

        MATLAB equivalent: ndi.session.creator_args()

        Returns:
            dict: Dictionary of constructor arguments

        Example:
            >>> args = session.creator_args()
            >>> new_session = SessionDir(**args)
        """
        return {
            'reference': self.reference,
        }

    @staticmethod
    def docinput2docs(
        session: 'Session',
        doc_input: Union[Document, List[Document], str, List[str]]
    ) -> List[Document]:
        """
        Convert various document input formats to list of Documents.

        MATLAB equivalent: ndi.session.docinput2docs()

        Converts document inputs (IDs, documents, lists) to a standardized
        list of Document objects.

        Args:
            session: Session object for database access
            doc_input: Document(s), ID(s), or mixed list

        Returns:
            List[Document]: List of document objects

        Example:
            >>> docs = Session.docinput2docs(session, ['id1', 'id2'])
            >>> docs = Session.docinput2docs(session, doc_obj)
        """
        # Handle None
        if doc_input is None:
            return []

        # Handle single document
        if isinstance(doc_input, Document):
            return [doc_input]

        # Handle single ID string
        if isinstance(doc_input, str):
            doc = session.database.read(doc_input)
            return [doc] if doc else []

        # Handle list
        if isinstance(doc_input, list):
            docs = []
            for item in doc_input:
                if isinstance(item, Document):
                    docs.append(item)
                elif isinstance(item, str):
                    doc = session.database.read(item)
                    if doc:
                        docs.append(doc)
            return docs

        # Unknown type
        return []

    @staticmethod
    def all_docs_in_session(
        docs: Union[Document, List[Document]],
        session_id: str
    ) -> tuple[bool, str]:
        """
        Validate that all documents belong to a session.

        MATLAB equivalent: ndi.session.all_docs_in_session()

        Checks that all provided documents have the specified session ID.

        Args:
            docs: Document or list of documents
            session_id: Expected session ID

        Returns:
            tuple: (all_match: bool, error_message: str)
                   If all_match is True, error_message is empty

        Example:
            >>> valid, msg = Session.all_docs_in_session(docs, session.id())
            >>> if not valid:
            ...     print(f'Validation failed: {msg}')
        """
        # Make list if needed
        if not isinstance(docs, list):
            docs = [docs]

        # Check each document
        for doc in docs:
            if not isinstance(doc, Document):
                continue

            doc_session_id = doc.session_id()
            if doc_session_id and doc_session_id != session_id:
                return (
                    False,
                    f"Document {doc.id()} has session_id {doc_session_id} "
                    f"which doesn't match {session_id}"
                )

        return (True, '')

    def validate_documents(
        self,
        document: Union[Document, List[Document]]
    ) -> tuple[bool, str]:
        """
        Validate whether documents belong to this session.

        MATLAB equivalent: ndi.session.validate_documents()

        Checks that all provided documents have session_id matching this
        session's ID. Empty session_ids (all zeros) are also acceptable.

        Args:
            document: Document or list of documents to validate

        Returns:
            tuple: (is_valid: bool, error_message: str)
                   If is_valid is True, error_message is empty

        Example:
            >>> valid, msg = session.validate_documents(doc)
            >>> if not valid:
            ...     print(f'Validation error: {msg}')
        """
        # Make list if needed
        if not isinstance(document, list):
            document = [document]

        # Check each document
        for i, doc in enumerate(document):
            # Must be a Document object
            if not isinstance(doc, Document):
                return (
                    False,
                    f'All entries must be Document objects (entry {i} is not)'
                )

            # Check session ID
            doc_session_id = doc.session_id()
            if not doc_session_id:
                continue  # None is OK

            # Must match this session or be empty
            if doc_session_id != self.id() and doc_session_id != Session.empty_id():
                return (
                    False,
                    f'Document {i} has session_id {doc_session_id} '
                    f'which does not match session id {self.id()}'
                )

        return (True, '')

    def ingest(self) -> tuple[bool, str]:
        """
        Ingest raw data and synchronization information into the database.

        MATLAB equivalent: ndi.session.ingest()

        Ingests all raw data and synchronization information from:
        1. The synchronization graph (syncgraph)
        2. All registered DAQ systems

        This creates ingested data documents that preserve the data
        even if the original raw files are removed.

        Returns:
            tuple: (success: bool, error_message: str)
                   If success is True, error_message is empty

        Raises:
            RuntimeError: If syncgraph is not initialized

        Example:
            >>> success, msg = session.ingest()
            >>> if not success:
            ...     print(f'Ingestion failed: {msg}')
        """
        error_msg = ''

        # Ingest syncgraph first
        if self.syncgraph is None:
            return (False, 'Syncgraph is not initialized')

        try:
            syncgraph_docs = self.syncgraph.ingest()
        except Exception as e:
            return (False, f'Error ingesting syncgraph: {str(e)}')

        # Get all DAQ systems
        daqs = self.daqsystem_load('name', '(.*)')  # Load all
        if not isinstance(daqs, list):
            daqs = [daqs] if daqs else []

        # Ingest each DAQ system
        daq_docs = []
        success = True
        for daq in daqs:
            try:
                daq_success, daq_doc_list = daq.ingest()
                daq_docs.append(daq_doc_list)
                if not daq_success:
                    success = False
                    error_msg = f'Error in DAQ system {daq.name}'
                    break
            except Exception as e:
                success = False
                error_msg = f'Error ingesting DAQ {daq.name}: {str(e)}'
                break

        # If ingestion failed, remove any added documents
        if not success:
            for doc_list in daq_docs:
                if doc_list:
                    try:
                        self.database_rm(doc_list)
                    except:
                        pass  # Best effort cleanup
            return (False, error_msg)

        # Success - add syncgraph documents
        if syncgraph_docs:
            self.database_add(syncgraph_docs)

        return (True, '')

    def is_fully_ingested(self) -> bool:
        """
        Check if the session is fully ingested.

        MATLAB equivalent: ndi.session.is_fully_ingested()

        Returns True if all DAQ systems in the session have been fully
        ingested (no remaining file navigators to process). Returns False
        if there are still elements on disk that need to be ingested.

        This method does not perform any ingestion itself - it only checks
        the status.

        Returns:
            bool: True if fully ingested, False otherwise

        Example:
            >>> if not session.is_fully_ingested():
            ...     session.ingest()
        """
        # Get all DAQ systems
        daqs = self.daqsystem_load('name', '(.*)')  # Load all
        if not isinstance(daqs, list):
            daqs = [daqs] if daqs else []

        # Check each DAQ system
        for daq in daqs:
            try:
                # Check if filenavigator has anything to ingest
                if hasattr(daq, 'filenavigator') and daq.filenavigator:
                    docs_out = daq.filenavigator.ingest()
                    if docs_out:  # If any documents, not fully ingested
                        return False
            except Exception:
                # If we can't check, assume not fully ingested
                return False

        return True

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
