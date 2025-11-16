"""
NDI Probe - Measurement or stimulation instruments.

Probes are instances of instruments that can MEASURE or STIMULATE.
They are typically associated with DAQ systems that perform data acquisition
or control stimulation.

A probe is uniquely identified by: session, name, reference, and type.
"""

from typing import Optional, List, Dict, Any, Tuple, Union
import numpy as np
from .element import Element
from .document import Document
from .time import TimeReference, ClockType
from .epoch import epochrange


class Probe(Element):
    """
    NDI Probe - base class for measurement or stimulation devices.

    Probes are physical elements that directly interface with subjects through
    DAQ systems. Examples: multichannel electrodes, cameras, speakers, LEDs.

    A probe is uniquely identified by:
        - session: The session where the probe is used
        - name: The name of the probe
        - reference: The reference number of the probe
        - type: The type of probe (see ndi.fun.probetype2objectinit)

    Examples:
        A multichannel extracellular electrode might be named 'extra',
        have reference=1, and type='n-trode'.

        If the electrode is moved, change the name or reference to indicate
        that data should not be combined across the two positions.

    Examples:
        >>> from ndi import Session
        >>> session = Session('/path/to/data')
        >>> probe = Probe(session, 'electrode1', 1, 'n-trode', 'subject_001')
        >>> # Or load from document:
        >>> probe = Probe(session, probe_doc)
    """

    def __init__(self, session, *args, **kwargs):
        """
        Create a Probe.

        Two forms:
        1. Probe(session, name, reference, type, subject_id)
        2. Probe(session, document)

        Args (Form 1):
            session: NDI Session object
            name: Probe name
            reference: Reference number
            type: Probe type
            subject_id: Subject ID

        Args (Form 2):
            session: NDI Session object
            document: NDI Document object or document ID
        """
        # Check if form 2 (document loading)
        if len(args) == 1 and (isinstance(args[0], Document) or isinstance(args[0], str)):
            # Load from document - delegate to Element
            super().__init__(session, args[0])
        elif len(args) >= 4:
            # Form 1: direct initialization
            # Remap arguments to Element constructor format
            name = args[0]
            reference = args[1]
            probe_type = args[2]
            subject_id = args[3] if len(args) > 3 else None

            # Probe is always direct and has no underlying element
            super().__init__(
                session=session,
                name=name,
                reference=reference,
                element_type=probe_type,
                underlying_element=None,
                direct=True,
                subject_id=subject_id
            )
        else:
            raise ValueError("Invalid arguments. Use Probe(session, name, ref, type, subject_id) or Probe(session, doc)")

    # Override Element methods

    def buildepochtable(self) -> List[Dict[str, Any]]:
        """
        Build the epoch table for this probe.

        Returns:
            List of epoch dicts

        Notes:
            Searches all DAQ systems in the session for epoch probe maps
            that match this probe's name, reference, and type.
        """
        et = []

        if self.session is None:
            return et

        # Pull all DAQ systems from the session
        # TODO: When daqsystem_load is implemented, use it
        # For now, return empty table
        # D = self.session.daqsystem_load('name', '(.*)')

        # Placeholder implementation
        # When DAQ system loading is available, this will:
        # 1. Get all DAQ systems from session
        # 2. For each DAQ system, get its epoch table
        # 3. For each epoch, check if epochprobemap matches this probe
        # 4. If match, create an epoch entry

        return et

    def epochclock(self, epoch_number: int) -> List[Any]:
        """
        Return clock types for this epoch.

        Args:
            epoch_number: Epoch number

        Returns:
            List of ClockType objects

        Notes:
            Returns the clock type(s) of the device this probe is based on.
        """
        et = self.epochtableentry(epoch_number)
        return et.get('epoch_clock', [])

    def issyncgraphroot(self) -> bool:
        """
        Should this object be a root in a syncgraph epoch graph?

        Returns:
            False (probes should add underlying DAQ system epochs to graph)

        Notes:
            For probes, we want to continue adding the underlying DAQ system
            epochs to the graph, so this returns False.
        """
        return False

    def epochsetname(self) -> str:
        """
        Return the name for epoch nodes in syncgraph.

        Returns:
            String name for this probe in epoch nodes
        """
        return f"probe: {self.elementstring()}"

    def probestring(self) -> str:
        """
        Get a human-readable probe string (DEPRECATED).

        Returns:
            Probe string in format: "name _ reference"

        Notes:
            This method is deprecated. Use elementstring() instead.
        """
        import warnings
        warnings.warn("probestring() is deprecated, use elementstring()", DeprecationWarning)
        return f"{self.name} _ {self.reference}"

    def getchanneldevinfo(self, epoch_number_or_id: Union[int, str]) -> Tuple[List, List[str], List[str], List[str], List[int]]:
        """
        Get device, channel type, and channel list for a given epoch.

        Args:
            epoch_number_or_id: Epoch number or epoch ID

        Returns:
            Tuple of (dev, devname, devepoch, channeltype, channellist) where:
            - dev: List of DAQ system objects for each channel
            - devname: List of device names for each channel
            - devepoch: List of epoch IDs on each device
            - channeltype: List of channel types
            - channellist: List of channel numbers

        Notes:
            Suppose there are C channels. Then each output list has C elements.
        """
        et, _ = self.epochtable()

        # Convert ID to number if needed
        if isinstance(epoch_number_or_id, str):
            epoch_number = None
            for i, e in enumerate(et):
                if e.get('epoch_id') == epoch_number_or_id:
                    epoch_number = i + 1
                    break
            if epoch_number is None:
                raise ValueError(f"Could not identify epoch with id {epoch_number_or_id}")
        else:
            epoch_number = epoch_number_or_id

        if epoch_number > len(et):
            raise ValueError(f"Epoch number {epoch_number} out of range 1..{len(et)}")

        epoch_entry = et[epoch_number - 1]

        dev = []
        devname = []
        devepoch = []
        channeltype = []
        channellist = []

        # Iterate through underlying epochs
        for underlying in epoch_entry.get('underlying_epochs', []):
            epm = underlying.get('epochprobemap', [])
            if not isinstance(epm, list):
                epm = [epm] if epm is not None else []

            for epm_entry in epm:
                if self.epochprobemapmatch(epm_entry):
                    # TODO: Parse devicestring when daqsystemstring is available
                    # devstr = ndi.daq.daqsystemstring(epm_entry.devicestring)
                    # devname_here, channeltype_here, channellist_here = devstr.ndi_daqsystemstring2channel()

                    # For now, placeholder
                    dev.append(underlying.get('underlying'))
                    devname.append('')  # Device name from devicestring
                    devepoch.append(underlying.get('epoch_id'))
                    channeltype.append([])  # Channel types from devicestring
                    channellist.append([])  # Channel numbers from devicestring

        return dev, devname, devepoch, channeltype, channellist

    def epochprobemapmatch(self, epochprobemap: Any) -> bool:
        """
        Check if an epoch probe map matches this probe.

        Args:
            epochprobemap: Epoch probe map object or dict to check

        Returns:
            True if the epoch probe map matches this probe's name, reference, and type

        Notes:
            Matches if all three criteria match:
            - name matches
            - reference matches
            - type matches (case-insensitive)
        """
        if epochprobemap is None:
            return False

        # Handle dict or object
        if isinstance(epochprobemap, dict):
            epm_name = epochprobemap.get('name', '')
            epm_ref = epochprobemap.get('reference', -1)
            epm_type = epochprobemap.get('type', '')
        else:
            epm_name = getattr(epochprobemap, 'name', '')
            epm_ref = getattr(epochprobemap, 'reference', -1)
            epm_type = getattr(epochprobemap, 'type', '')

        return (self.name == epm_name and
                self.reference == epm_ref and
                self.type.lower() == epm_type.lower())

    # TimeSeries methods

    def readtimeseries(self, timeref_or_epoch: Union[TimeReference, int, str],
                      t0: float, t1: float) -> Tuple[np.ndarray, Union[np.ndarray, dict], TimeReference]:
        """
        Read timeseries data from this probe via DAQ systems.

        Args:
            timeref_or_epoch: Either a TimeReference object or an epoch number/ID
            t0: Start time
            t1: End time

        Returns:
            Tuple of (data, t, timeref) where:
            - data: Time series data array
            - t: Time information (array or dict)
            - timeref: The time reference used

        Notes:
            Probes read data from DAQ systems. This method:
            1. Converts time reference to dev_local_time
            2. Finds epoch ranges spanning the requested time
            3. Reads data from each epoch via readtimeseriesepoch()
            4. Concatenates data and converts times back to requested reference
        """
        # Create or validate time reference
        if isinstance(timeref_or_epoch, TimeReference):
            timeref = timeref_or_epoch
        else:
            # Create time reference with dev_local_time
            timeref = TimeReference(self, ClockType('dev_local_time'), timeref_or_epoch, 0)

        if self.session is None or not hasattr(self.session, 'syncgraph'):
            raise ValueError("Probe must have a session with syncgraph")

        # Convert times to dev_local_time
        epoch_t0_out, epoch0_timeref, msg = self.session.syncgraph.time_convert(
            timeref, t0, self, ClockType('dev_local_time')
        )
        epoch_t1_out, epoch1_timeref, msg = self.session.syncgraph.time_convert(
            timeref, t1, self, ClockType('dev_local_time')
        )

        if epoch0_timeref is None or epoch1_timeref is None:
            raise ValueError(f"Could not find time mapping (maybe wrong epoch name?): {msg}")

        # Get epoch range
        er, et, gt0_t1 = epochrange(
            epoch0_timeref.referent,
            ClockType('dev_local_time'),
            epoch0_timeref.epoch,
            epoch1_timeref.epoch
        )

        epoch = epoch0_timeref.epoch

        data = []
        t = []

        # Read data from each epoch in range
        for i, epoch_id in enumerate(er):
            # Determine start and end times for this epoch
            if i == 0:
                start_time = epoch_t0_out
            else:
                start_time = gt0_t1[i][0]

            if i == len(er) - 1:
                stop_time = epoch_t1_out
            else:
                stop_time = gt0_t1[i][1]

            # Read epoch data
            try:
                data_here, t_here = self.readtimeseriesepoch(epoch_id, start_time, stop_time)

                # Handle dimension mismatch (sometimes readers are a sample short)
                if isinstance(t_here, np.ndarray):
                    t_here = t_here.flatten()
                    if data_here.shape[0] == len(t_here) - 1:
                        t_here = t_here[:-1]

                data.append(data_here)

                # Convert times back to requested reference
                epoch_here_timeref = TimeReference(
                    epoch0_timeref.referent,
                    epoch0_timeref.clocktype,
                    epoch_id,
                    epoch0_timeref.time
                )

                if isinstance(t_here, np.ndarray):
                    # Numeric time array
                    t_here = self.session.syncgraph.time_convert(
                        epoch_here_timeref, t_here,
                        timeref.referent, timeref.clocktype
                    )
                    t.append(t_here)
                elif isinstance(t_here, dict):
                    # Structured time (for events, markers, etc.)
                    t_converted = {}
                    for field_name, field_data in t_here.items():
                        if not isinstance(field_data, (list, tuple)):
                            # Convert single array
                            field_converted = self.session.syncgraph.time_convert(
                                epoch_here_timeref, field_data,
                                timeref.referent, timeref.clocktype
                            )
                            t_converted[field_name] = field_converted
                        else:
                            # Convert list of arrays (for cell arrays)
                            field_converted = []
                            for item in field_data:
                                item_converted = self.session.syncgraph.time_convert(
                                    epoch_here_timeref, item,
                                    timeref.referent, timeref.clocktype
                                )
                                field_converted.append(item_converted)
                            t_converted[field_name] = field_converted

                    t.append(t_converted)

            except Exception as e:
                # If reading fails, continue to next epoch
                # TODO: Log warning
                pass

        # Concatenate data and times
        if data:
            if isinstance(data[0], np.ndarray):
                data = np.concatenate(data, axis=0)
            else:
                data = np.array([])

            if t and isinstance(t[0], np.ndarray):
                t = np.concatenate(t, axis=0)
            elif t and isinstance(t[0], dict):
                # Merge dicts
                t_merged = {}
                for t_dict in t:
                    for key, val in t_dict.items():
                        if key not in t_merged:
                            t_merged[key] = []
                        if isinstance(val, list):
                            t_merged[key].extend(val)
                        else:
                            t_merged[key].append(val)
                # Concatenate arrays in merged dict
                for key in t_merged:
                    if isinstance(t_merged[key], list) and len(t_merged[key]) > 0:
                        if isinstance(t_merged[key][0], np.ndarray):
                            t_merged[key] = np.concatenate(t_merged[key], axis=0)
                t = t_merged
            else:
                t = np.array([])
        else:
            data = np.array([])
            t = np.array([])

        return data, t, timeref

    def readtimeseriesepoch(self, epoch_id: str, t0: float, t1: float) -> Tuple[np.ndarray, np.ndarray]:
        """
        Read timeseries data for a single epoch.

        Args:
            epoch_id: Epoch identifier
            t0: Start time (in epoch's dev_local_time)
            t1: End time (in epoch's dev_local_time)

        Returns:
            Tuple of (data, t)

        Notes:
            This is an abstract method that should be overridden by subclasses.
            Subclasses implement the actual data reading from specific hardware.

            For example, ndi.probe.timeseries.mfdaq would read from the
            DAQ system's channels.
        """
        raise NotImplementedError("Subclasses must implement readtimeseriesepoch()")

    def __eq__(self, other: 'Probe') -> bool:
        """
        Check equality of two probes.

        Args:
            other: Another Probe object

        Returns:
            True if objects share class, session, and probe string

        Notes:
            Two probes are equal if they have the same session, element string,
            and type.
        """
        if not isinstance(other, Probe):
            return False

        return (self.session == other.session and
                self.elementstring() == other.elementstring() and
                self.type == other.type)

    def __repr__(self) -> str:
        """String representation."""
        return f"Probe(name='{self.name}', type='{self.type}', ref={self.reference})"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()

    # Static methods

    @staticmethod
    def buildmultipleepochtables(probe_list: List['Probe']) -> List[List[Dict[str, Any]]]:
        """
        Build epoch tables for multiple probes efficiently.

        Args:
            probe_list: List of Probe objects

        Returns:
            List of epoch tables (one per probe)

        Notes:
            This method is more efficient than calling buildepochtable()
            for each probe individually because it minimizes redundant
            operations by using indexing and checking the session cache.

            All probes must belong to the same session.

        Examples:
            >>> probes = [probe1, probe2, probe3]
            >>> tables = Probe.buildmultipleepochtables(probes)
            >>> # tables[0] is probe1's epoch table
        """
        num_probes = len(probe_list)
        et_list = [[] for _ in range(num_probes)]

        if num_probes == 0:
            return et_list

        # Step 1: Check cache and prepare index for probes that need building
        needs_build_idx = []
        probes_to_build_map = {}

        for p in range(num_probes):
            probe = probe_list[p]
            cached_et, _ = probe.cached_epochtable()
            if cached_et is not None:
                et_list[p] = cached_et
            else:
                needs_build_idx.append(p)
                map_key = f"{probe.name} | {probe.reference} | {probe.type.lower()}"
                if map_key not in probes_to_build_map:
                    probes_to_build_map[map_key] = []
                probes_to_build_map[map_key].append(p)

        if not needs_build_idx:
            return et_list  # All were cached

        # Step 2: Verify all probes belong to same session
        my_session = probe_list[needs_build_idx[0]].session
        for i in needs_build_idx[1:]:
            if probe_list[i].session != my_session:
                raise ValueError("All probes must belong to the same session")

        # Step 3: Build epoch tables efficiently
        # TODO: When daqsystem_load is available, implement efficient batch building
        # For now, just call buildepochtable for each probe
        for p in needs_build_idx:
            et_list[p] = probe_list[p].buildepochtable()

            # Cache the result
            cache, key = probe_list[p].getcache()
            if cache is not None and key is not None:
                hashvalue = hash(str(et_list[p]))
                priority = 1
                cache.add(key, 'epochtable-hash',
                         {'epochtable': et_list[p], 'hashvalue': hashvalue},
                         priority)

        return et_list
