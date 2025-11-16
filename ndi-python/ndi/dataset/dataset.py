"""
NDI Dataset - Multi-session container for managing experimental datasets.

This module provides functionality for managing collections of NDI sessions,
including linked and ingested sessions, with unified database access across
all contained sessions.

Ported from MATLAB: src/ndi/+ndi/dataset.m
"""

from typing import List, Dict, Tuple, Union, Optional, Any
from pathlib import Path
import warnings

from ..document import Document
from ..query import Query
from ..ido import IDO


class Dataset:
    """
    NDI Dataset - manages a collection of experimental sessions.

    A dataset provides:
    - Container for multiple sessions (linked or ingested)
    - Unified database operations across sessions
    - Session metadata management
    - Cross-session search and analysis

    The Dataset class is abstract - use a concrete subclass like dataset.Dir
    for actual instantiation.

    Attributes:
        session_info (List[Dict]): Metadata about contained sessions
        session_array (List[Dict]): Array of session objects and IDs
        session: Internal session for dataset-level documents
    """

    def __init__(self, reference: str):
        """
        Create a new Dataset object (abstract - use subclass like dataset.Dir).

        Args:
            reference: String reference for the dataset

        Note:
            This is typically called from a subclass. End users should use
            concrete implementations like ndi.dataset.Dir.

        See Also:
            ndi.dataset.Dir
        """
        self.reference = reference
        self.session_info: List[Dict[str, Any]] = []
        self.session_array: List[Dict[str, Any]] = []
        self.session = None  # To be set by subclass

    def id(self) -> str:
        """
        Return the identifier of this dataset.

        Returns:
            str: Unique identifier for the dataset

        Example:
            >>> dataset = Dataset('my_experiment')
            >>> print(dataset.id())
            'a1b2c3d4e5f6...'
        """
        if self.session is None:
            raise RuntimeError("Dataset session not initialized")
        return self.session.id()

    def reference(self) -> str:
        """
        Return the reference string for this dataset.

        Returns:
            str: Reference string (not necessarily unique)

        Note:
            The reference is a human-readable identifier, while the ID
            returned by id() is guaranteed unique.

        See Also:
            id()
        """
        if self.session is None:
            raise RuntimeError("Dataset session not initialized")
        return self.session.reference

    def add_linked_session(self, ndi_session_obj) -> 'Dataset':
        """
        Link an ndi.session to this dataset without ingesting.

        This adds a session to the dataset by reference, keeping the session
        in its original location. The session is not copied into the dataset.

        Args:
            ndi_session_obj: ndi.session object to link

        Returns:
            Dataset: Self for chaining

        Raises:
            ValueError: If session is already part of the dataset

        Example:
            >>> from ndi.session import SessionDir
            >>> session = SessionDir('/path/to/session', 'session_ref')
            >>> dataset.add_linked_session(session)

        See Also:
            add_ingested_session(), session_list()
        """
        # Ensure session_info is built
        if not self.session_array:
            self.build_session_info()

        # Check if session is already in the dataset
        session_ids = [info['session_id'] for info in self.session_info]
        if ndi_session_obj.id() in session_ids:
            raise ValueError(
                f"ndi.session object with id {ndi_session_obj.id()} "
                f"is already part of dataset {self.id()}"
            )

        # Create session info entry
        session_info_here = {
            'session_id': ndi_session_obj.id(),
            'session_reference': ndi_session_obj.reference,
            'is_linked': 1,
            'session_creator': type(ndi_session_obj).__module__ + '.' + type(ndi_session_obj).__name__,
        }

        # Get creator arguments
        creator_args = ndi_session_obj.creator_args()

        # Store up to 6 creator arguments (matching MATLAB behavior)
        for i in range(6):
            field_name = f'session_creator_input{i+1}'
            if isinstance(creator_args, dict):
                # If creator_args is a dict, extract values
                keys = list(creator_args.keys())
                session_info_here[field_name] = creator_args.get(keys[i], '') if i < len(keys) else ''
            elif isinstance(creator_args, (list, tuple)):
                session_info_here[field_name] = creator_args[i] if i < len(creator_args) else ''
            else:
                session_info_here[field_name] = ''

        # Add to session info and session array
        self.session_info.append(session_info_here)
        self.session_array.append({
            'session_id': ndi_session_obj.id(),
            'session': ndi_session_obj
        })

        # Save session info to database
        self._save_session_info()

        return self

    def add_ingested_session(self, ndi_session_obj) -> 'Dataset':
        """
        Ingest an ndi.session into this dataset by copying documents.

        This adds a session to the dataset by copying all its documents
        into the dataset. The session must be fully ingested before this
        operation.

        Args:
            ndi_session_obj: ndi.session object to ingest

        Returns:
            Dataset: Self for chaining

        Raises:
            ValueError: If session is already in dataset or not fully ingested

        Example:
            >>> from ndi.session import SessionDir
            >>> session = SessionDir('/path/to/session', 'session_ref')
            >>> session.ingest()  # Ensure fully ingested
            >>> dataset.add_ingested_session(session)

        See Also:
            add_linked_session(), session_list()
        """
        # Ensure session_info is built
        if not self.session_array:
            self.build_session_info()

        # Check if session is already in the dataset
        session_ids = [info['session_id'] for info in self.session_info]
        if ndi_session_obj.id() in session_ids:
            raise ValueError(
                f"ndi.session object with id {ndi_session_obj.id()} "
                f"is already part of dataset {self.id()}"
            )

        # Check if session is fully ingested
        is_fully_ingested = ndi_session_obj.is_fully_ingested()
        if not is_fully_ingested:
            raise ValueError(
                f"ndi.session object with id {ndi_session_obj.id()} "
                f"and reference {ndi_session_obj.reference} is not yet fully ingested. "
                f"It must be fully ingested before it can be added in ingested form to a dataset."
            )

        # Create session info entry
        session_info_here = {
            'session_id': ndi_session_obj.id(),
            'session_reference': ndi_session_obj.reference,
            'session_creator': type(ndi_session_obj).__module__ + '.' + type(ndi_session_obj).__name__,
            'is_linked': 0,
        }

        # Get creator arguments
        creator_args = ndi_session_obj.creator_args()

        # Store up to 6 creator arguments
        for i in range(6):
            field_name = f'session_creator_input{i+1}'
            if isinstance(creator_args, dict):
                keys = list(creator_args.keys())
                session_info_here[field_name] = creator_args.get(keys[i], '') if i < len(keys) else ''
            elif isinstance(creator_args, (list, tuple)):
                session_info_here[field_name] = creator_args[i] if i < len(creator_args) else ''
            else:
                session_info_here[field_name] = ''

        # Handle special case for session.dir (MATLAB kludge)
        from ..session import SessionDir
        if isinstance(ndi_session_obj, SessionDir):
            session_info_here['session_creator_input2'] = ''  # Same relative path
        else:
            raise NotImplementedError(
                f"Not smart enough to add ingested sessions of type "
                f"{type(ndi_session_obj).__name__} yet."
            )

        # Copy session documents to dataset
        from ..db.fun.copy_session_to_dataset import copy_session_to_dataset
        success, error_msg = copy_session_to_dataset(ndi_session_obj, self)
        if not success:
            raise RuntimeError(f"Failed to copy session to dataset: {error_msg}")

        # Add to session info and session array
        self.session_info.append(session_info_here)
        self.session_array.append({
            'session_id': ndi_session_obj.id(),
            'session': None  # Will be opened on demand
        })

        # Save session info to database
        self._save_session_info()

        return self

    def open_session(self, session_id: str):
        """
        Open an ndi.session object from this dataset.

        Args:
            session_id: Session identifier

        Returns:
            Session object

        Raises:
            ValueError: If session_id not found in dataset

        Example:
            >>> sessions_refs, session_ids = dataset.session_list()
            >>> session = dataset.open_session(session_ids[0])

        See Also:
            session_list()
        """
        # Ensure session info is built
        if not self.session_array:
            self.build_session_info()

        # Find session in arrays
        array_match = None
        info_match = None

        for i, entry in enumerate(self.session_array):
            if entry['session_id'] == session_id:
                array_match = i
                break

        for i, info in enumerate(self.session_info):
            if info['session_id'] == session_id:
                info_match = i
                break

        if array_match is None:
            raise ValueError(
                f"session_id {session_id} not found in dataset {self.id()}"
            )

        # Return if already open
        if self.session_array[array_match]['session'] is not None:
            return self.session_array[array_match]['session']

        # Open the session
        info = self.session_info[info_match]

        # Determine path argument
        patharg = info['session_creator_input2']
        if info['is_linked'] == 0:
            patharg = self.getpath()

        # Get the session class
        session_creator = info['session_creator']

        # Import the appropriate session class
        if 'SessionDir' in session_creator or 'session.dir' in session_creator:
            from ..session import SessionDir
            session_class = SessionDir
        else:
            # Try dynamic import
            parts = session_creator.rsplit('.', 1)
            if len(parts) == 2:
                module_name, class_name = parts
                import importlib
                module = importlib.import_module(module_name)
                session_class = getattr(module, class_name)
            else:
                raise ValueError(f"Cannot parse session creator: {session_creator}")

        # Create session instance
        # Note: Assuming SessionDir constructor takes (path, reference, session_id)
        # This matches MATLAB's ndi.session.dir(reference, path, session_id)
        ndi_session_obj = session_class(
            path=patharg,
            reference=info['session_creator_input1'],
            session_id=session_id
        )

        # Store in array
        self.session_array[array_match]['session'] = ndi_session_obj

        return ndi_session_obj

    def session_list(self) -> Tuple[List[str], List[str]]:
        """
        Return the session reference/identifier list for this dataset.

        Returns:
            tuple: (ref_list, id_list)
                - ref_list: List of session reference strings
                - id_list: List of session unique identifier strings
                The nth entry of ref_list corresponds to the nth entry of id_list

        Example:
            >>> refs, ids = dataset.session_list()
            >>> for ref, id in zip(refs, ids):
            ...     print(f'{ref}: {id}')
        """
        if not self.session_info:
            self.build_session_info()

        ref_list = [info['session_reference'] for info in self.session_info]
        id_list = [info['session_id'] for info in self.session_info]

        return ref_list, id_list

    def getpath(self) -> str:
        """
        Return the path of the dataset.

        Returns:
            str: Path or URL reference to storage location

        Note:
            The path is some sort of reference to the storage location of
            the dataset. This might be a URL, or a file directory, depending
            upon the subclass.

            In the base Dataset class, this delegates to the internal session.

        See Also:
            ndi.dataset.Dir
        """
        if self.session is None:
            raise RuntimeError("Dataset session not initialized")
        return self.session.getpath()

    # Database methods

    def database_add(self, document: Union[Document, List[Document]]) -> 'Dataset':
        """
        Add document(s) to the dataset.

        If the base.session_id of each document matches one of the sessions
        in the dataset, the document will be added to that session. If the
        base.session_id matches the dataset ID, it will be added to the
        dataset itself.

        Args:
            document: ndi.document object or list of documents

        Returns:
            Dataset: Self for chaining

        Example:
            >>> doc = dataset.session.newdocument('base')
            >>> dataset.database_add(doc)

        See Also:
            database_search(), database_rm()
        """
        # Ensure list
        if not isinstance(document, list):
            document = [document]

        # Extract unique session IDs
        ndi_session_ids_here = []
        for doc in document:
            session_id = doc.document_properties.get('base', {}).get('session_id', '')
            ndi_session_ids_here.append(session_id)

        # Get unique session IDs (excluding empty)
        from ..session import Session
        empty_id = Session.empty_id()
        usession_ids = list(set(ndi_session_ids_here))
        usession_ids = [sid for sid in usession_ids if sid != empty_id]

        # Open all sessions that will receive documents
        sessions = {}
        for session_id in usession_ids:
            if session_id == self.id():
                sessions[session_id] = self.session
            else:
                sessions[session_id] = self.open_session(session_id)

        # Add documents to appropriate sessions
        for session_id in usession_ids:
            # Find documents for this session
            docs_for_session = []
            for i, doc_session_id in enumerate(ndi_session_ids_here):
                if doc_session_id == session_id or doc_session_id == empty_id:
                    docs_for_session.append(document[i])

            if docs_for_session:
                sessions[session_id].database_add(docs_for_session)

        return self

    def database_rm(
        self,
        doc_or_id: Union[str, Document, List],
        err_if_not_found: bool = False
    ) -> 'Dataset':
        """
        Remove document(s) from the dataset.

        If the base.session_id of each document matches one of the linked
        sessions, the document will be removed from that session. If removed
        from a linked session, it will also be removed when that session is
        opened individually.

        Args:
            doc_or_id: Document unique ID, ndi.document, or list
            err_if_not_found: Raise error if ID not found (default False)

        Returns:
            Dataset: Self for chaining

        Raises:
            ValueError: If err_if_not_found=True and document not found

        Example:
            >>> dataset.database_rm(doc)
            >>> dataset.database_rm('document_id_string')

        See Also:
            database_add(), database_search()
        """
        # Convert to documents
        from ..session import Session
        doc_input = Session.docinput2docs(self.session, doc_or_id)

        if not doc_input:
            if err_if_not_found:
                raise ValueError("Document(s) not found")
            return self

        # Extract unique session IDs
        ndi_session_ids_here = []
        for doc in doc_input:
            session_id = doc.document_properties.get('base', {}).get('session_id', '')
            ndi_session_ids_here.append(session_id)

        # Get unique session IDs (excluding empty)
        empty_id = Session.empty_id()
        usession_ids = list(set(ndi_session_ids_here))
        usession_ids = [sid for sid in usession_ids if sid != empty_id]

        # Open all sessions
        sessions = {}
        for session_id in usession_ids:
            if session_id == self.id():
                sessions[session_id] = self.session
            else:
                sessions[session_id] = self.open_session(session_id)

        # Remove documents from appropriate sessions
        for session_id in usession_ids:
            # Find documents for this session
            docs_for_session = []
            for i, doc_session_id in enumerate(ndi_session_ids_here):
                if doc_session_id == session_id or doc_session_id == empty_id:
                    docs_for_session.append(doc_input[i])

            if docs_for_session:
                try:
                    sessions[session_id].database_rm(docs_for_session)
                except Exception as e:
                    if err_if_not_found:
                        raise

        return self

    def database_search(self, searchparameters: Query) -> List[Document]:
        """
        Search for documents in the dataset database.

        Searches across all sessions in the dataset (both dataset-level
        documents and linked session documents).

        Args:
            searchparameters: ndi.query object

        Returns:
            List[Document]: Matching documents

        Example:
            >>> from ndi.query import Query
            >>> query = Query('', 'isa', 'element')
            >>> docs = dataset.database_search(query)

        See Also:
            database_add(), database_rm()
        """
        # Search dataset's own session
        ndi_document_obj = self.session.database.search(searchparameters)

        # Open all linked sessions and search them
        self._open_linked_sessions()

        linked_indices = [
            i for i, info in enumerate(self.session_info)
            if info.get('is_linked', 0) == 1
        ]

        for idx in linked_indices:
            session = self.session_array[idx]['session']
            if session is not None:
                linked_docs = session.database_search(searchparameters)
                ndi_document_obj.extend(linked_docs)

        return ndi_document_obj

    def database_openbinarydoc(
        self,
        ndi_document_or_id: Union[str, Document],
        filename: str,
        auto_close: bool = True
    ):
        """
        Open the binary document channel of a document.

        Args:
            ndi_document_or_id: Document or document ID
            filename: Binary filename
            auto_close: Automatically close when object goes out of scope

        Returns:
            Binary document object

        Note:
            Must be closed with database_closebinarydoc()

        Example:
            >>> bd = dataset.database_openbinarydoc(doc, 'data.bin')
            >>> # ... read from bd ...
            >>> dataset.database_closebinarydoc(bd)

        See Also:
            database_closebinarydoc(), database_existbinarydoc()
        """
        return self.session.database_openbinarydoc(
            ndi_document_or_id, filename, auto_close=auto_close
        )

    def database_existbinarydoc(
        self,
        ndi_document_or_id: Union[str, Document],
        filename: str
    ) -> Tuple[bool, str]:
        """
        Check if a binary document exists.

        Args:
            ndi_document_or_id: Document or document ID
            filename: Binary filename

        Returns:
            tuple: (exists, file_path)
                - exists: True if file exists
                - file_path: Full path to file (empty if not exists)

        Example:
            >>> exists, path = dataset.database_existbinarydoc(doc, 'data.bin')
            >>> if exists:
            ...     print(f'File at: {path}')
        """
        return self.session.database_existbinarydoc(ndi_document_or_id, filename)

    def database_closebinarydoc(self, ndi_binarydoc_obj) -> None:
        """
        Close a binary document.

        Args:
            ndi_binarydoc_obj: Binary document object to close

        See Also:
            database_openbinarydoc()
        """
        return self.session.database_closebinarydoc(ndi_binarydoc_obj)

    def document_session(self, ndi_document_obj: Document):
        """
        Return the session that contains a document.

        Args:
            ndi_document_obj: Document object

        Returns:
            Session object containing the document

        Example:
            >>> session = dataset.document_session(doc)
            >>> print(session.reference)
        """
        session_id = ndi_document_obj.document_properties.get('base', {}).get('session_id', '')
        if not session_id:
            raise ValueError("Document has no session_id")
        return self.open_session(session_id)

    # Protected methods

    def build_session_info(self) -> None:
        """
        Build the session info data structure for this dataset.

        Builds the internal 'session_array' and 'session_info' structures
        by reading from the database.

        This is called automatically when needed.
        """
        # Query for dataset session info document
        q = (
            Query('', 'isa', 'dataset_session_info') &
            Query('base.session_id', 'exact_string', self.id())
        )
        session_info_doc = self.session.database_search(q)

        if not session_info_doc:
            # No sessions yet - initialize empty
            self.session_info = []
        else:
            if len(session_info_doc) > 1:
                raise RuntimeError(
                    f"Found {len(session_info_doc)} dataset session info documents "
                    f"for dataset {self.id()} (expected 1)"
                )

            # Extract session info from document
            doc_props = session_info_doc[0].document_properties
            dataset_info = doc_props.get('dataset_session_info', {})
            self.session_info = dataset_info.get('dataset_session_info', [])

        # Build session array from session info
        self.session_array = []
        for info in self.session_info:
            self.session_array.append({
                'session_id': info['session_id'],
                'session': None  # Initially don't open
            })

    def _open_linked_sessions(self) -> None:
        """
        Ensure all linked sessions are open.

        Opens all linked sessions if they are not already open.
        """
        if not self.session_info:
            self.build_session_info()

        for i, info in enumerate(self.session_info):
            if info.get('is_linked', 0) == 1:
                if self.session_array[i]['session'] is None:
                    self.open_session(info['session_id'])

    def _save_session_info(self) -> None:
        """
        Save session info to the database.

        Creates or updates the dataset_session_info document.
        """
        # Create document with session info
        d = Document(
            'dataset_session_info',
            **{'dataset_session_info.dataset_session_info': self.session_info}
        )

        # Search for existing session info document
        q = Query('', 'isa', 'dataset_session_info')
        existing_docs = self.session.database_search(q)

        # Remove existing documents
        if existing_docs:
            self.session.database_rm(existing_docs)

        # Set session ID and add
        d = d.set_session_id(self.id())
        self.session.database_add(d)

    def __repr__(self) -> str:
        """String representation."""
        return (
            f"Dataset(reference='{self.reference if isinstance(self.reference, str) else self.reference()}', "
            f"id='{self.id()[:8]}...', sessions={len(self.session_info)})"
        )
