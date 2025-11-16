"""
NDI DAQ Reader - Base class for reading data from acquisition systems.
"""

from typing import List, Dict, Any, Optional, Tuple
from abc import ABC, abstractmethod

from ..ido import IDO
from ..document import Document
from ..query import Query


class Reader(IDO, ABC):
    """
    NDI DAQ Reader - abstract base class for data acquisition readers.

    The Reader class provides the interface for reading data from various
    data acquisition systems. Specific readers (e.g., Intan, Blackrock)
    inherit from this class and implement format-specific methods.

    Attributes:
        None in base class - subclasses may add format-specific attributes

    Examples:
        >>> # Subclass example (actual implementations in reader/ subdirectory)
        >>> from ndi.daq.reader import MFDAQReader
        >>> # reader = MFDAQReader()
    """

    def __init__(self):
        """Create a new DAQ Reader."""
        super().__init__()

    def epochclock(self, epochfiles: List[str]) -> List[Any]:
        """
        Return the clock types available for this set of epoch files.

        Args:
            epochfiles: List of epoch file paths

        Returns:
            List of ClockType objects

        Notes:
            Base class returns 'no_time' clock type.
            Subclasses should override to provide actual clock types.
        """
        from ..time import ClockType
        return [ClockType('no_time')]

    def epochclock_ingested(self, epochfiles: List[str], session) -> List[Any]:
        """
        Return clock types for ingested epoch files.

        Args:
            epochfiles: List of epoch file paths
            session: NDI Session object

        Returns:
            List of ClockType objects from ingested document
        """
        d = self.getingesteddocument(epochfiles, session)
        if d is None:
            return self.epochclock(epochfiles)

        ec_list = d.document_properties.get('daqreader_epochdata_ingested', {})\
                                       .get('epochtable', {})\
                                       .get('epochclock', [])

        if not ec_list:
            return self.epochclock(epochfiles)

        from ..time import ClockType
        result = []
        for ec in ec_list:
            if isinstance(ec, str):
                result.append(ClockType(ec))
            else:
                result.append(ec)
        return result

    def t0_t1(self, epochfiles: List[str]) -> List[List[float]]:
        """
        Return beginning and end times for the epoch.

        Args:
            epochfiles: List of epoch file paths

        Returns:
            List of [t0, t1] pairs for each clock type

        Notes:
            Base class returns [[NaN, NaN]].
            Subclasses should override to provide actual times.
        """
        import math
        return [[math.nan, math.nan]]

    def t0_t1_ingested(self, epochfiles: List[str], session) -> List[List[float]]:
        """
        Return beginning and end times for ingested epoch files.

        Args:
            epochfiles: List of epoch file paths
            session: NDI Session object

        Returns:
            List of [t0, t1] pairs from ingested document
        """
        d = self.getingesteddocument(epochfiles, session)
        if d is None:
            return self.t0_t1(epochfiles)

        t0t1 = d.document_properties.get('daqreader_epochdata_ingested', {})\
                                    .get('epochtable', {})\
                                    .get('t0_t1', [[]])

        # Handle conversion from JSON (may not be in cell array format)
        if not isinstance(t0t1, list):
            return [[t0t1[0], t0t1[1]]]
        elif len(t0t1) > 0 and not isinstance(t0t1[0], list):
            return [t0t1]

        return t0t1 if t0t1 else [[]]

    def verifyepochprobemap(self, epochprobemap: Any, epochfiles: List[str]) -> Tuple[bool, str]:
        """
        Verify that an epoch probe map is compatible with the data.

        Args:
            epochprobemap: Epoch probe map to verify
            epochfiles: List of epoch file paths

        Returns:
            Tuple of (is_valid, error_message)

        Notes:
            Base class only checks if epochprobemap is of correct type.
            Subclasses should implement more specific validation.
        """
        # TODO: Check isinstance of epochprobemap_daqsystem when implemented
        # For now, basic validation
        msg = ''
        b = isinstance(epochprobemap, (dict, list, type(None)))
        if not b:
            msg = 'epochprobemap must be dict, list, or None'
        return b, msg

    def ingest_epochfiles(self, epochfiles: List[str], epoch_id: str = '') -> Document:
        """
        Create a document that describes data read by this reader.

        Args:
            epochfiles: List of epoch file paths
            epoch_id: Epoch ID string

        Returns:
            Document of type 'daqreader_epochdata_ingested'

        Notes:
            The document is not added to any database.
            Subclasses should override to add format-specific data.
        """
        from ..time import ClockType

        # Get epoch clock and t0_t1
        ec = self.epochclock(epochfiles)
        ec_strings = [ct.type if isinstance(ct, ClockType) else str(ct) for ct in ec]

        t0t1 = self.t0_t1(epochfiles)

        # Convert t0_t1 to array format
        import numpy as np
        if len(t0t1) > 0 and isinstance(t0t1[0], list):
            t0t1_array = np.array(t0t1)
        else:
            t0t1_array = np.array([t0t1])

        daqreader_epochdata_ingested = {
            'epochtable': {
                'epochclock': ec_strings,
                't0_t1': t0t1_array.tolist()
            }
        }

        d = Document('daqreader_epochdata_ingested',
                    daqreader_epochdata_ingested=daqreader_epochdata_ingested)
        d = d.set_dependency_value('daqreader_id', self.id())

        return d

    def getingesteddocument(self, epochfiles: List[str], session) -> Optional[Document]:
        """
        Retrieve the ingested document for this epoch.

        Args:
            epochfiles: List of epoch file paths
            session: NDI Session object

        Returns:
            Ingested document, or None if not found

        Notes:
            Searches the session database for ingested epoch data.
        """
        if session is None:
            return None

        # Search for ingested document with this reader's ID
        # TODO: Also filter by epoch files when file tracking is implemented
        q = Query('daqreader_epochdata_ingested.daqreader_id', 'exact_string', self.id())

        try:
            docs = session.database_search(q)
            if len(docs) > 0:
                return docs[0]
        except:
            pass

        return None

    def ingested2epochs_t0t1_epochclock(self, session) -> Dict[str, Dict[str, Any]]:
        """
        Map ingested epochs to their t0_t1 and epochclock values.

        Args:
            session: NDI Session object

        Returns:
            Dictionary with 'epochclock' and 't0t1' subdictionaries,
            each mapping epoch_id to values

        Notes:
            Used by DAQ system to populate epoch tables from ingested data.
        """
        result = {
            'epochclock': {},
            't0t1': {}
        }

        if session is None:
            return result

        # Search for all ingested documents for this reader
        q = Query('daqreader_epochdata_ingested.daqreader_id', 'exact_string', self.id())

        try:
            docs = session.database_search(q)
            for doc in docs:
                # Extract epoch_id if available
                epoch_id = doc.document_properties.get('epochid', {}).get('epochid', '')
                if not epoch_id:
                    continue

                # Extract epochclock
                ec = doc.document_properties.get('daqreader_epochdata_ingested', {})\
                                           .get('epochtable', {})\
                                           .get('epochclock', [])
                if ec:
                    from ..time import ClockType
                    result['epochclock'][epoch_id] = [
                        ClockType(e) if isinstance(e, str) else e for e in ec
                    ]

                # Extract t0_t1
                t0t1 = doc.document_properties.get('daqreader_epochdata_ingested', {})\
                                              .get('epochtable', {})\
                                              .get('t0_t1', [])
                if t0t1:
                    result['t0t1'][epoch_id] = t0t1

        except Exception as e:
            # If search fails, return empty result
            pass

        return result

    def __eq__(self, other: 'Reader') -> bool:
        """
        Test whether two DAQ readers are equal.

        Args:
            other: Another Reader object

        Returns:
            True if same class and same ID
        """
        if not isinstance(other, Reader):
            return False
        return (type(self) == type(other) and self.id() == other.id())

    def newdocument(self) -> Document:
        """
        Create a new document for this DAQ reader.

        Returns:
            Document object representing this reader
        """
        doc = Document('daqreader',
                      daqreader_ndi_daqreader_class=f"{self.__class__.__module__}.{self.__class__.__name__}")
        doc.document_properties['base']['id'] = self.id()
        doc.document_properties['base']['session_id'] = ''  # No session for bare reader

        return doc

    def searchquery(self) -> Query:
        """
        Create a search query for this DAQ reader.

        Returns:
            Query object that searches by ID
        """
        return Query('base.id', 'exact_string', self.id())

    def __repr__(self) -> str:
        """String representation."""
        return f"{self.__class__.__name__}(id='{self.id()}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
