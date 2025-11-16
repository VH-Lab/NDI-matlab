"""
NDI DAQ System - Main DAQ system class that combines file navigation and data reading.
"""

from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path

from ..ido import IDO
from ..document import Document
from ..epoch import EpochSet
from ..query import Query


class System(IDO, EpochSet):
    """
    NDI DAQ System - manages data acquisition devices and their epochs.

    The System class combines a file navigator (for finding epoch files) with
    a DAQ reader (for reading the actual data). It inherits from EpochSet to
    provide epoch-based data access.

    Attributes:
        name: Name of the DAQ system
        filenavigator: File navigator object (TODO: implement when file.navigator is ready)
        daqreader: DAQ reader object for reading data
        daqmetadatareader: List of metadata readers (optional)

    Examples:
        >>> from ndi import Session
        >>> from ndi.daq import System
        >>> session = Session('/path/to/session')
        >>> # filenavigator and daqreader will be implemented later
        >>> # system = System('my_daq', filenavigator, daqreader)
    """

    def __init__(self, name: str, filenavigator=None, daqreader=None,
                 daqmetadatareader: Optional[List[Any]] = None):
        """
        Create a new DAQ System.

        Args:
            name: Name of the DAQ system
            filenavigator: File navigator object (TODO: implement)
            daqreader: DAQ reader object
            daqmetadatareader: List of metadata readers (optional)

        Notes:
            File navigator and DAQ reader implementations are pending.
            This base structure is ready for integration when those
            components are implemented.
        """
        IDO.__init__(self)
        EpochSet.__init__(self)

        self.name = name
        self.filenavigator = filenavigator
        self.daqreader = daqreader
        self.daqmetadatareader = daqmetadatareader if daqmetadatareader is not None else []

    def epochclock(self, epoch_number: int) -> List[Any]:
        """
        Return the clock types available for this epoch.

        Args:
            epoch_number: Epoch number (1-indexed)

        Returns:
            List of ClockType objects for this epoch

        Notes:
            In the base class, returns 'no_time' clock type.
            Subclasses should override to provide actual clock types.
        """
        from ..time import ClockType
        return [ClockType('no_time')]

    def t0_t1(self, epoch_number: int) -> List[List[float]]:
        """
        Return beginning and end times for the epoch.

        Args:
            epoch_number: Epoch number (1-indexed)

        Returns:
            List of [t0, t1] pairs for each clock type

        Notes:
            In the base class, returns [[NaN, NaN]].
            Subclasses should override to provide actual times.
        """
        import math
        return [[math.nan, math.nan]]

    def epochid(self, epoch_number: int) -> str:
        """
        Return the epoch ID for the given epoch number.

        Args:
            epoch_number: Epoch number (1-indexed)

        Returns:
            Epoch ID string

        Notes:
            This is determined by the associated filenavigator.
            Returns empty string if no filenavigator is available.
        """
        if self.filenavigator is not None:
            return self.filenavigator.epochid(epoch_number)
        return ""

    def getprobes(self) -> List[Dict[str, Any]]:
        """
        Return all probes associated with this DAQ system.

        Returns:
            List of probe dictionaries with fields:
            - name: Probe name
            - reference: Probe reference
            - type: Probe type
            - subject_id: Subject ID

        Notes:
            Extracts unique probes from all epoch probe maps.
            Requires epochtable to be built.
        """
        et, _ = self.epochtable()

        probes = []
        seen = set()

        for epoch_entry in et:
            epc = epoch_entry.get('epochprobemap', [])
            if epc:
                for ec in epc:
                    # TODO: Implement daqsystemstring parsing when available
                    # For now, simple name matching
                    probe_key = (ec.get('name', ''),
                               ec.get('reference', ''),
                               ec.get('type', ''),
                               ec.get('subjectstring', ''))

                    if probe_key not in seen:
                        seen.add(probe_key)
                        probes.append({
                            'name': ec.get('name', ''),
                            'reference': ec.get('reference', ''),
                            'type': ec.get('type', ''),
                            'subject_id': ec.get('subjectstring', '')
                        })

        return probes

    def session(self):
        """
        Return the session object associated with this DAQ system.

        Returns:
            Session object from the filenavigator

        Notes:
            Returns None if no filenavigator is available.
        """
        if self.filenavigator is not None:
            return self.filenavigator.session
        return None

    def setsession(self, session):
        """
        Set the session for this DAQ system's filenavigator.

        Args:
            session: NDI Session object

        Returns:
            Self for chaining
        """
        if self.filenavigator is not None:
            self.filenavigator = self.filenavigator.setsession(session)
        return self

    def deleteepoch(self, number: int, removedata: bool = False):
        """
        Delete an epoch and epoch record from the device.

        Args:
            number: Epoch number to delete
            removedata: If True, physically delete data; if False, rename but keep

        Raises:
            NotImplementedError: Not yet implemented
        """
        raise NotImplementedError("deleteepoch not yet implemented")

    def getcache(self) -> Tuple[Optional[Any], Optional[str]]:
        """
        Return the cache and key for this DAQ system.

        Returns:
            Tuple of (cache, key) where:
            - cache: Session cache object (or None)
            - key: Cache key string (or None)
        """
        cache = None
        key = None

        session_obj = self.session()
        if session_obj is not None and hasattr(session_obj, 'cache'):
            cache = session_obj.cache
            key = f'daqsystem_{self.id()}'

        return cache, key

    def buildepochtable(self) -> List[Dict[str, Any]]:
        """
        Build the epoch table for this DAQ system.

        Returns:
            List of epoch dictionaries

        Notes:
            Combines information from:
            1. File navigator's epoch table
            2. DAQ reader's ingested epoch info (if available)
            3. Epoch probe maps
        """
        if self.filenavigator is None:
            return []

        # Get base epoch table from filenavigator
        # TODO: When filenavigator is implemented, this will work
        et = getattr(self.filenavigator, 'epochtable', [])

        # Get ingested epoch mapping from daqreader
        if self.daqreader is not None and self.session() is not None:
            m = self.daqreader.ingested2epochs_t0t1_epochclock(self.session())

            # Update each epoch entry
            for i, epoch_entry in enumerate(et):
                epoch_num = epoch_entry.get('epoch_number', i + 1)
                epoch_id = epoch_entry.get('epoch_id', '')

                # Update epochprobemap
                epm = epoch_entry.get('epochprobemap')
                epoch_entry['epochprobemap'] = self.getepochprobemap(epoch_num, epm)

                # Update epoch_clock
                if epoch_id in m.get('epochclock', {}):
                    epoch_entry['epoch_clock'] = m['epochclock'][epoch_id]
                else:
                    epoch_entry['epoch_clock'] = self.epochclock(epoch_num)

                # Update t0_t1
                if epoch_id in m.get('t0t1', {}):
                    epoch_entry['t0_t1'] = m['t0t1'][epoch_id]
                else:
                    epoch_entry['t0_t1'] = self.t0_t1(epoch_num)

        return et

    def epochprobemapfilename(self, epochnumber: int) -> str:
        """
        Return the filename for the epoch probe map file for an epoch.

        Args:
            epochnumber: Epoch number

        Returns:
            Full path to epoch probe map file

        Notes:
            Returns empty string if no filenavigator available.
        """
        if self.filenavigator is not None:
            return self.filenavigator.epochprobemapfilename(epochnumber)
        return ""

    def verifyepochprobemap(self, epochprobemap: Any, epoch: int) -> Tuple[bool, str]:
        """
        Verify that an epoch probe map is compatible with this device and data.

        Args:
            epochprobemap: Epoch probe map object to verify
            epoch: Epoch number

        Returns:
            Tuple of (is_valid, error_message)

        Notes:
            Delegates verification to the DAQ reader.
        """
        if self.filenavigator is None or self.daqreader is None:
            return False, "No filenavigator or daqreader available"

        epochfiles = self.filenavigator.getepochfiles(epoch)
        return self.daqreader.verifyepochprobemap(epochprobemap, epochfiles)

    def getepochprobemap(self, epoch: int, filenav_epochprobemap: Any = None) -> Any:
        """
        Return the epoch probe map for an epoch.

        Args:
            epoch: Epoch number or ID
            filenav_epochprobemap: Epoch probe map from filenavigator (optional)

        Returns:
            Epoch probe map object

        Notes:
            Checks if the daqreader has a getepochprobemap method.
            If so, uses that. Otherwise, uses filenavigator's version.
        """
        if self.daqreader is not None and hasattr(self.daqreader, 'getepochprobemap'):
            ecfname = self.epochprobemapfilename(epoch)
            if self.filenavigator is not None:
                epochfiles = self.filenavigator.getepochfiles(epoch)
                return self.daqreader.getepochprobemap(ecfname, epochfiles)

        return filenav_epochprobemap

    def newdocument(self) -> Document:
        """
        Create an NDI document for this DAQ system.

        Returns:
            Document object representing this DAQ system
        """
        session_obj = self.session()
        session_id = session_obj.id() if session_obj is not None else ''

        doc = Document('daqsystem',
                      daqsystem_name=self.name,
                      daqsystem_class=f"{self.__class__.__module__}.{self.__class__.__name__}")
        doc.document_properties['base']['id'] = self.id()
        doc.document_properties['base']['session_id'] = session_id

        # Add dependency to daqreader
        if self.daqreader is not None:
            doc = doc.set_dependency_value('daqreader_id', self.daqreader.id())

        return doc

    def searchquery(self) -> Query:
        """
        Create a search query for this DAQ system.

        Returns:
            Query object that searches by ID and session ID
        """
        q = Query('base.id', 'exact_string', self.id())
        session_obj = self.session()
        if session_obj is not None:
            q = q & Query('base.session_id', 'exact_string', session_obj.id())
        return q

    def __eq__(self, other: 'System') -> bool:
        """Check equality of two DAQ systems."""
        if not isinstance(other, System):
            return False
        return (self.name == other.name and
                self.id() == other.id())

    def __repr__(self) -> str:
        """String representation."""
        return f"System(name='{self.name}', id='{self.id()}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
