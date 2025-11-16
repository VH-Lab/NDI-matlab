"""
NDI Element - Physical or logical measurement/stimulation elements.

Elements are objects that can measure or stimulate, including physical probes
and logical derived data elements.
"""

from typing import Optional, List, Dict, Any, Tuple
from .ido import IDO
from .epoch import EpochSet
from .document import Document
from .query import Query


class Element(IDO, EpochSet):
    """
    NDI Element - represents a measurement or stimulation element.

    Elements can be physical (probes) or logical (derived data, inferred neurons, etc.).
    They are uniquely identified by: session, name, reference, and type.

    Attributes:
        session: NDI Session object
        name: Element name (must start with letter, no whitespace)
        reference: Reference number (non-negative integer)
        type: Type of element (must start with letter, no whitespace)
        underlying_element: Parent element if this derives from another element
        direct: Whether this directly uses underlying epochs (True) or adds its own (False)
        subject_id: ID of associated subject
        dependencies: Additional dependencies beyond underlying_element and subject_id

    Examples:
        >>> from ndi import Session
        >>> session = Session('/path/to/data')
        >>> element = Element(session, 'myelem', 1, 'generic')
        >>> # Or load from document:
        >>> element = Element(session, element_doc)
    """

    def __init__(self, session, *args, **kwargs):
        """
        Create an Element.

        Two forms:
        1. Element(session, name, reference, type, underlying_element, direct, subject_id, dependencies)
        2. Element(session, document)

        Args (Form 1):
            session: NDI Session object
            name: Element name
            reference: Reference number
            type: Element type
            underlying_element: Parent element (optional)
            direct: Whether epochs are directly from underlying (default True)
            subject_id: Subject ID (optional)
            dependencies: Additional dependencies dict (optional)

        Args (Form 2):
            session: NDI Session object
            document: NDI Document object or document ID string
        """
        IDO.__init__(self)
        EpochSet.__init__(self)

        # Check if loading from document (form 2)
        if len(args) == 1 and (isinstance(args[0], Document) or isinstance(args[0], str)):
            self._init_from_document(session, args[0])
        elif len(args) >= 3:
            # Form 1: direct initialization
            self._init_from_params(session, *args, **kwargs)
        else:
            raise ValueError("Invalid arguments. Use Element(session, name, ref, type, ...) or Element(session, doc)")

    def _init_from_params(self, session, name: str, reference: int, element_type: str,
                         underlying_element: Optional['Element'] = None,
                         direct: bool = True,
                         subject_id: Optional[str] = None,
                         dependencies: Optional[Dict] = None):
        """Initialize from parameters."""
        self.session = session
        self.name = name
        self.reference = int(reference)
        self.type = element_type
        self.underlying_element = underlying_element
        self.direct = bool(direct)

        # Get subject_id from underlying element if not provided
        if underlying_element is not None:
            if not isinstance(underlying_element, Element):
                raise ValueError("Underlying element must be an Element instance")
            self.subject_id = underlying_element.subject_id
            if subject_id is not None:
                import warnings
                warnings.warn("Ignoring input subject_id because underlying element is given")
        else:
            self.subject_id = subject_id or ''

        self.dependencies = dependencies or {}

    def _init_from_document(self, session, doc_or_id):
        """Initialize from document."""
        if not hasattr(session, 'database_search'):
            raise ValueError("Session must have database_search method")

        # Get document if ID was provided
        if isinstance(doc_or_id, str):
            docs = session.database_search(Query('base.id', 'exact_string', doc_or_id))
            if len(docs) != 1:
                raise ValueError(f"Document with ID {doc_or_id} not found")
            doc = docs[0]
        else:
            doc = doc_or_id

        # Validate document type
        if 'element' not in doc.document_properties:
            raise ValueError("This document does not have 'element' properties")

        # Extract properties
        elem_props = doc.document_properties['element']
        self.session = session
        self.name = elem_props['name']
        self.reference = int(elem_props['reference'])
        self.type = elem_props['type']

        # Get direct flag
        direct_val = elem_props.get('direct', True)
        if isinstance(direct_val, str):
            self.direct = eval(direct_val)
        else:
            self.direct = bool(direct_val)

        # Get underlying element
        underlying_id = doc.dependency_value('underlying_element_id')
        if underlying_id and underlying_id != '':
            # TODO: Implement ndi_document2ndi_object when available
            # For now, we'll store the ID and load on demand
            self.underlying_element = None  # Placeholder
        else:
            self.underlying_element = None

        # Get subject_id
        self.subject_id = doc.dependency_value('subject_id') or ''

        # Get dependencies (excluding subject_id and underlying_element_id)
        dep_names, dep_values = doc.dependency()
        self.dependencies = {}
        for name, value in zip(dep_names, dep_values):
            if name not in ('subject_id', 'underlying_element_id'):
                self.dependencies[name] = value

        # Set identifier from document
        self.identifier = doc.id()

    # EpochSet methods

    def issyncgraphroot(self) -> bool:
        """
        Should this object be a root in a syncgraph epoch graph?

        Returns:
            True if this has no underlying element (should be root), False otherwise

        Notes:
            Elements with underlying elements should continue to add those
            underlying epochs to the graph.
        """
        return self.underlying_element is None

    def epochsetname(self) -> str:
        """
        Return the name for epoch nodes in syncgraph.

        Returns:
            String name for this element in epoch nodes
        """
        return f"element: {self.elementstring()}"

    def epochclock(self, epoch_number: int) -> List[Any]:
        """
        Return clock types available for this epoch.

        Args:
            epoch_number: Epoch number

        Returns:
            List of ClockType objects

        Notes:
            Returns the clock type(s) of the underlying element/epochs.
        """
        et = self.epochtableentry(epoch_number)
        return et.get('epoch_clock', [])

    def t0_t1(self, epoch_number: int) -> List[List[float]]:
        """
        Return beginning and end times for the epoch.

        Args:
            epoch_number: Epoch number

        Returns:
            List of [t0, t1] pairs for each clock type
        """
        et = self.epochtableentry(epoch_number)
        return et.get('t0_t1', [])

    def getcache(self) -> Tuple[Optional[Any], Optional[str]]:
        """
        Get the cache and key for this element.

        Returns:
            Tuple of (cache, key) where:
            - cache: Session cache object (or None)
            - key: Cache key string (or None)

        Notes:
            Key is elementstring + '|' + type.
        """
        cache = None
        key = None

        if self.session is not None and hasattr(self.session, 'cache'):
            cache = self.session.cache
            key = f"{self.elementstring()} | {self.type}"

        return cache, key

    def buildepochtable(self) -> List[Dict[str, Any]]:
        """
        Build the epoch table for this element.

        Returns:
            List of epoch dicts

        Notes:
            For direct elements, epochs come directly from underlying element.
            For non-direct elements, epochs are loaded from database and matched
            to underlying element epochs.
        """
        et = []

        epoch_mapping = True

        # Get underlying epoch table
        underlying_et = []
        if self.underlying_element is not None:
            underlying_et, _ = self.underlying_element.epochtable()

        if self.direct:
            # Direct: use underlying epochs as-is
            ia = list(range(len(underlying_et)))
            ib = list(range(len(underlying_et)))
        else:
            # Non-direct: load added epochs and match to underlying
            et_added = self.loadaddedepochs()

            if self.underlying_element is None:
                # No underlying element: use all added epochs
                ia = list(range(len(et_added)))
                ib = []
            else:
                # Match added epochs to underlying epochs by epoch_id
                added_ids = [e.get('epoch_id') for e in et_added]
                underlying_ids = [e.get('epoch_id') for e in underlying_et]

                # Find intersection
                ia = []
                ib = []
                for i, aid in enumerate(added_ids):
                    try:
                        j = underlying_ids.index(aid)
                        ia.append(i)
                        ib.append(j)
                    except ValueError:
                        pass

                if not ia:
                    # Legal to have no mapping
                    epoch_mapping = False
                    ia = list(range(len(et_added)))
                    ib = list(range(len(et_added)))

        # Build epoch table
        for n in range(len(ia)):
            et_entry = {
                'epoch_number': n + 1,
                'epoch_session_id': self.session.id() if self.session else ''
            }

            # Set epoch_id
            if self.underlying_element is not None:
                if epoch_mapping and ib:
                    et_entry['epoch_id'] = underlying_et[ib[n]].get('epoch_id', '')
                else:
                    et_entry['epoch_id'] = et_added[ia[n]].get('epoch_id', '') if not self.direct else underlying_et[ib[n]].get('epoch_id', '')
            else:
                if not self.direct:
                    et_entry['epoch_id'] = et_added[ia[n]].get('epoch_id', '')
                else:
                    et_entry['epoch_id'] = ''

            # Set clock, t0_t1, epochprobemap
            if self.direct and ib:
                et_entry['epoch_clock'] = underlying_et[ib[n]].get('epoch_clock', [])
                et_entry['t0_t1'] = underlying_et[ib[n]].get('t0_t1', [])
                et_entry['epochprobemap'] = underlying_et[ib[n]].get('epochprobemap')
            else:
                et_entry['epochprobemap'] = None
                if not self.direct and ia:
                    et_entry['epoch_clock'] = et_added[ia[n]].get('epoch_clock', [])
                    et_entry['t0_t1'] = et_added[ia[n]].get('t0_t1', [])
                else:
                    et_entry['epoch_clock'] = []
                    et_entry['t0_t1'] = []

            # Set underlying_epochs
            underlying_epochs = []
            if self.underlying_element is not None and ib:
                underlying_epoch = {
                    'underlying': self.underlying_element,
                    'epoch_id': underlying_et[ib[n]].get('epoch_id', ''),
                    'epoch_session_id': underlying_et[ib[n]].get('epoch_session_id', ''),
                    'epochprobemap': underlying_et[ib[n]].get('epochprobemap'),
                    'epoch_clock': underlying_et[ib[n]].get('epoch_clock', []),
                    't0_t1': underlying_et[ib[n]].get('t0_t1', [])
                }
                underlying_epochs.append(underlying_epoch)

            et_entry['underlying_epochs'] = underlying_epochs
            et.append(et_entry)

        return et

    # Element-specific methods

    def elementstring(self) -> str:
        """
        Get a human-readable element string.

        Returns:
            String in format: "name | reference"
        """
        return f"{self.name} | {self.reference}"

    def addepoch(self, epochid: str, epochclock, t0_t1: List[float],
                add_to_db: bool = False, epochids: Optional[List[str]] = None) -> Optional[Document]:
        """
        Add an epoch to this element.

        Args:
            epochid: Epoch ID to add
            epochclock: ClockType object or string
            t0_t1: [t0, t1] pair for this epoch
            add_to_db: Whether to add document to database
            epochids: Optional list of original epoch IDs (for oneepoch documents)

        Returns:
            Epoch document if created, None otherwise

        Raises:
            ValueError: If element is direct or not in database
        """
        if self.direct:
            raise ValueError("Cannot add external observations to a direct element")

        if self.session is None:
            return None

        # Find element document in database
        element_docs = self.session.database_search(self.searchquery())
        if len(element_docs) == 0:
            raise ValueError("Element is not part of the database")
        elif len(element_docs) > 1:
            raise ValueError("More than one document corresponds to this element")

        element_doc = element_docs[0]

        # Convert clocktype to string
        from .time import ClockType
        if isinstance(epochclock, ClockType):
            epochclock_str = epochclock.type
        else:
            epochclock_str = str(epochclock)

        # Prepare t0_t1
        import numpy as np
        if len(t0_t1) == 2:
            t0_t1_input = [float(t0_t1[0]), float(t0_t1[1])]
        else:
            t0_t1_input = t0_t1

        # Create document
        if epochids is None:
            epoch_doc = Document('element_epoch',
                                element_epoch={'epoch_clock': epochclock_str, 't0_t1': t0_t1_input},
                                epochid={'epochid': epochid})
        else:
            epoch_doc = Document('oneepoch',
                                element_epoch={'epoch_clock': epochclock_str, 't0_t1': t0_t1_input},
                                epochid={'epochid': epochid},
                                oneepoch={'epoch_ids': epochids})

        epoch_doc = epoch_doc.set_dependency_value('element_id', element_doc.id())

        if add_to_db:
            self.session.database_add(epoch_doc)

        return epoch_doc

    def loadaddedepochs(self) -> List[Dict[str, Any]]:
        """
        Load added/registered epochs from the database.

        Returns:
            List of epoch dicts with fields:
            - epoch_number
            - epoch_id
            - epochprobemap (None)
            - epoch_clock
            - t0_t1
            - underlying_epochs (empty list)

        Notes:
            Only works for non-direct elements.
            For direct elements, returns empty list.
        """
        et_added = []

        if self.direct:
            return et_added

        if self.session is None:
            return et_added

        # Find element document
        try:
            element_docs = self.session.database_search(self.searchquery())
            if len(element_docs) != 1:
                return et_added
            element_doc = element_docs[0]
        except:
            return et_added

        # Search for element_epoch and oneepoch documents
        q1 = Query('element_epoch.element_id', 'exact_string', element_doc.id())
        q2 = Query('oneepoch.element_id', 'exact_string', element_doc.id())
        q = q1 | q2

        try:
            epoch_docs = self.session.database_search(q)
        except:
            epoch_docs = []

        # Build epoch table from documents
        for i, doc in enumerate(epoch_docs):
            epoch_entry = {
                'epoch_number': i + 1,
                'epoch_id': doc.document_properties.get('epochid', {}).get('epochid', ''),
                'epochprobemap': None,
                'epoch_clock': [],
                't0_t1': [],
                'underlying_epochs': []
            }

            # Get epoch_clock and t0_t1
            elem_epoch = doc.document_properties.get('element_epoch', {})
            if 'epoch_clock' in elem_epoch:
                from .time import ClockType
                clock_str = elem_epoch['epoch_clock']
                if isinstance(clock_str, str):
                    epoch_entry['epoch_clock'] = [ClockType(clock_str)]
                else:
                    epoch_entry['epoch_clock'] = clock_str

            if 't0_t1' in elem_epoch:
                epoch_entry['t0_t1'] = [elem_epoch['t0_t1']]

            et_added.append(epoch_entry)

        return et_added

    def epochtableentry(self, epoch_number: int) -> Dict[str, Any]:
        """
        Get a single epoch table entry by epoch number.

        Args:
            epoch_number: Epoch number (1-indexed)

        Returns:
            Epoch dict

        Raises:
            IndexError: If epoch_number out of range
        """
        et, _ = self.epochtable()
        if epoch_number < 1 or epoch_number > len(et):
            raise IndexError(f"Epoch number {epoch_number} out of range 1..{len(et)}")
        return et[epoch_number - 1]

    # Document service methods

    def newdocument(self) -> Document:
        """
        Create an NDI document for this element.

        Returns:
            Document object representing this element
        """
        doc = Document('element',
                      element={
                          'ndi_element_class': f"{self.__class__.__module__}.{self.__class__.__name__}",
                          'name': self.name,
                          'reference': self.reference,
                          'type': self.type,
                          'direct': self.direct
                      })

        doc.document_properties['base']['id'] = self.id()
        if self.session is not None:
            doc.document_properties['base']['session_id'] = self.session.id()

        # Set dependencies
        underlying_id = ''
        if self.underlying_element:
            underlying_id = self.underlying_element.id()

        doc = doc.set_dependency_value('underlying_element_id', underlying_id)
        doc = doc.set_dependency_value('subject_id', self.subject_id or '')

        # Add other dependencies
        for name, value in self.dependencies.items():
            doc = doc.set_dependency_value(name, value)

        return doc

    def searchquery(self) -> Query:
        """
        Create a search query for this element.

        Returns:
            Query object that searches by session, name, type, and reference
        """
        if self.session is None:
            q = Query('element.name', 'exact_string', self.name)
        else:
            q = Query('base.session_id', 'exact_string', self.session.id())
            q = q & Query('element.name', 'exact_string', self.name)

        q = q & Query('element.type', 'exact_string', self.type)
        q = q & Query('element.reference', 'exact_number', self.reference)

        return q

    def __eq__(self, other: 'Element') -> bool:
        """Check equality of two elements."""
        if not isinstance(other, Element):
            return False
        return (self.session == other.session and
                self.elementstring() == other.elementstring() and
                self.type == other.type)

    def __repr__(self) -> str:
        """String representation."""
        return f"Element(name='{self.name}', type='{self.type}', ref={self.reference})"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
