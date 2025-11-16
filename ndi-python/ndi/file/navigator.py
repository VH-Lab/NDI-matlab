"""
NDI File Navigator - Navigate file structures for epoch-based data access.

The Navigator manages finding and organizing files on disk into epochs for data acquisition.
"""

from typing import Optional, List, Dict, Any, Tuple
from pathlib import Path
import os
import json

from ..ido import IDO
from ..epoch import EpochSet
from ..document import Document
from ..query import Query


class Navigator(IDO, EpochSet):
    """
    NDI File Navigator - manages file-based epoch organization.

    The Navigator class negotiates the data tree of DAQ system data stored
    on disk, organizing files into epochs and providing access to epoch metadata.

    Attributes:
        session: NDI Session object
        fileparameters: Parameters for finding files in each epoch
        epochprobemap_fileparameters: Parameters for finding epochprobemap files
        epochprobemap_class: Class name for epoch probe maps

    Examples:
        >>> from ndi import Session
        >>> from ndi.file import Navigator
        >>> session = Session('/path/to/data')
        >>> # Simple file matching
        >>> nav = Navigator(session, {'filematch': ['*.rhd']})
        >>> # Or load from document
        >>> nav = Navigator(session, nav_doc)
    """

    def __init__(self, session, fileparameters=None, epochprobemap_class: str = None,
                 epochprobemap_fileparameters=None):
        """
        Create a File Navigator.

        Two forms:
        1. Navigator(session, fileparameters, epochprobemap_class, epochprobemap_fileparameters)
        2. Navigator(session, document)

        Args (Form 1):
            session: NDI Session object
            fileparameters: File matching parameters (dict or string)
            epochprobemap_class: Class for epoch probe maps (default: 'ndi.epoch.epochprobemap_daqsystem')
            epochprobemap_fileparameters: Parameters for finding epochprobemap files

        Args (Form 2):
            session: NDI Session object
            document: NDI Document object with filenavigator properties
        """
        IDO.__init__(self)
        EpochSet.__init__(self)

        # Check if loading from document (form 2)
        if isinstance(fileparameters, Document):
            self._init_from_document(session, fileparameters)
        else:
            # Form 1: direct initialization
            self._init_from_params(session, fileparameters, epochprobemap_class,
                                  epochprobemap_fileparameters)

        # Initialize cached epoch filenames
        self._cached_epochfilenames = {}

    def _init_from_params(self, session, fileparameters, epochprobemap_class,
                         epochprobemap_fileparameters):
        """Initialize from parameters."""
        if session is not None:
            if not hasattr(session, 'database_search'):
                raise ValueError("session must be an NDI Session object")
            self.session = session
        else:
            self.session = None

        # Set file parameters
        if fileparameters is not None:
            self.setfileparameters(fileparameters)
        else:
            self.fileparameters = {}

        # Set epoch probe map class
        if epochprobemap_class is not None:
            self.epochprobemap_class = epochprobemap_class
        else:
            self.epochprobemap_class = 'ndi.epoch.epochprobemap_daqsystem'

        # Set epoch probe map file parameters
        if epochprobemap_fileparameters is not None:
            self.setepochprobemapfileparameters(epochprobemap_fileparameters)
        else:
            self.epochprobemap_fileparameters = {}

    def _init_from_document(self, session, doc: Document):
        """Initialize from document."""
        if 'filenavigator' not in doc.document_properties:
            raise ValueError("Document does not have 'filenavigator' properties")

        nav_props = doc.document_properties['filenavigator']

        self.session = session

        # Extract fileparameters
        if nav_props.get('fileparameters'):
            try:
                self.fileparameters = eval(nav_props['fileparameters'])
            except:
                self.fileparameters = nav_props['fileparameters']
        else:
            self.fileparameters = {}

        # Extract epochprobemap_class
        self.epochprobemap_class = nav_props.get('epochprobemap_class',
                                                 'ndi.epoch.epochprobemap_daqsystem')

        # Extract epochprobemap_fileparameters
        if nav_props.get('epochprobemap_fileparameters'):
            try:
                self.epochprobemap_fileparameters = eval(nav_props['epochprobemap_fileparameters'])
            except:
                self.epochprobemap_fileparameters = nav_props['epochprobemap_fileparameters']
        else:
            self.epochprobemap_fileparameters = {}

        # Set identifier from document
        self.identifier = doc.id()

    # File parameters

    def setfileparameters(self, thefileparameters):
        """
        Set the file parameters for epoch file matching.

        Args:
            thefileparameters: String, list of strings, or dict with 'filematch' key
                Examples:
                - '.*\\.ext$'  (regex pattern)
                - ['myfile1.ext1', 'myfile2.ext2']  (exact filenames)
                - {'filematch': ['#.ext1', 'myfile#.ext2']}  (# is wildcard)

        Notes:
            File parameters specify which files comprise an epoch.
            Complex file matching with # wildcards will be implemented.
        """
        if isinstance(thefileparameters, str):
            self.fileparameters = {'filematch': [thefileparameters]}
        elif isinstance(thefileparameters, list):
            self.fileparameters = {'filematch': thefileparameters}
        elif isinstance(thefileparameters, dict):
            self.fileparameters = thefileparameters
        else:
            raise ValueError("fileparameters must be string, list, or dict")

    def setepochprobemapfileparameters(self, theparameters):
        """
        Set parameters for finding epoch probe map files.

        Args:
            theparameters: String, list, or dict with 'filematch' key

        Notes:
            Specifies how to find the epochprobemap file among epoch files.
        """
        if isinstance(theparameters, str):
            self.epochprobemap_fileparameters = {'filematch': [theparameters]}
        elif isinstance(theparameters, list):
            self.epochprobemap_fileparameters = {'filematch': theparameters}
        elif isinstance(theparameters, dict):
            self.epochprobemap_fileparameters = theparameters
        else:
            raise ValueError("epochprobemap_fileparameters must be string, list, or dict")

    # Epoch management

    def buildepochtable(self) -> List[Dict[str, Any]]:
        """
        Build the epoch table from file groups.

        Returns:
            List of epoch dicts

        Notes:
            Groups files into epochs based on fileparameters,
            loads epoch probe maps, and assigns epoch IDs.
        """
        # Get file groups for each epoch
        all_epochs, epochprobemaps = self.selectfilegroups()

        et = []

        for i, epoch_files in enumerate(all_epochs):
            epoch_number = i + 1

            # Get epoch ID
            eid = self.epochid(epoch_number, epoch_files)

            # Get epoch probe map
            if epochprobemaps and i < len(epochprobemaps) and epochprobemaps[i]:
                epm = epochprobemaps[i]
            else:
                epm = self.getepochprobemap(epoch_number, epoch_files)

            # Get clock and time info (file navigator doesn't keep time)
            from ..time import ClockType
            epoch_clock = [ClockType('no_time')]
            t0_t1 = [[float('nan'), float('nan')]]

            # Build underlying epochs
            underlying_epoch = {
                'underlying': epoch_files,
                'epoch_id': eid,
                'epoch_session_id': self.session.id() if self.session else '',
                'epochprobemap': None,
                'epoch_clock': epoch_clock,
                't0_t1': t0_t1
            }

            # Build epoch entry
            epoch_entry = {
                'epoch_number': epoch_number,
                'epoch_id': eid,
                'epoch_session_id': self.session.id() if self.session else '',
                'epochprobemap': epm,
                'epoch_clock': epoch_clock,
                't0_t1': t0_t1,
                'underlying_epochs': [underlying_epoch]
            }

            et.append(epoch_entry)

        return et

    def selectfilegroups(self) -> Tuple[List[List[str]], List[Any]]:
        """
        Select and group files into epochs.

        Returns:
            Tuple of (all_epochs, epochprobemaps) where:
            - all_epochs: List of file lists (one per epoch)
            - epochprobemaps: List of epoch probe maps (one per epoch)

        Notes:
            Combines epochs from disk and ingested epochs in database.
        """
        # Step 1: Find epochs on disk
        epochfiles_disk = self.selectfilegroups_disk()

        # Step 2: See if we have any ingested epochs
        d_ingested = []
        if self.session is not None:
            try:
                # Check for ingested epochs
                epoch_query = (
                    Query('', 'isa', 'epochfiles_ingested') &
                    Query('', 'depends_on', 'filenavigator_id', self.id()) &
                    Query('base.session_id', 'exact_string', self.session.id())
                )
                d_ingested = self.session.database_search(epoch_query)
            except:
                d_ingested = []

        if not d_ingested:
            # Nothing ingested
            all_epochs = epochfiles_disk
            epochprobemaps = [None] * len(all_epochs)
            return all_epochs, epochprobemaps

        # Step 3: Reconcile epochs on disk and those that are ingested
        epoch_id_disk = []
        for i, files in enumerate(epochfiles_disk):
            epoch_id_disk.append(self.epochid(i + 1, files))

        epoch_id_ingested = [
            doc.document_properties.get('epochfiles_ingested', {}).get('epoch_id', '')
            for doc in d_ingested
        ]

        # Combine unique epoch IDs
        all_ids = epoch_id_ingested + epoch_id_disk
        unique_ids = []
        unique_indices = []
        for i, eid in enumerate(all_ids):
            if eid not in unique_ids:
                unique_ids.append(eid)
                unique_indices.append(i)

        all_epochs = []
        epochprobemaps = []
        for idx in unique_indices:
            if idx < len(epoch_id_ingested):
                # From ingested
                doc = d_ingested[idx]
                files = doc.document_properties.get('epochfiles_ingested', {}).get('files', [])
                epm_data = doc.document_properties.get('epochfiles_ingested', {}).get('epochprobemap', None)
                if epm_data:
                    # Deserialize epoch probe map
                    # TODO: Use epochprobemap_class to create proper object
                    epm = epm_data  # Placeholder
                else:
                    epm = None
                all_epochs.append(files)
                epochprobemaps.append(epm)
            else:
                # From disk
                disk_idx = idx - len(epoch_id_ingested)
                all_epochs.append(epochfiles_disk[disk_idx])
                epochprobemaps.append(None)

        return all_epochs, epochprobemaps

    def selectfilegroups_disk(self) -> List[List[str]]:
        """
        Select groups of files on disk that comprise epochs.

        Returns:
            List of file lists (one per epoch)

        Notes:
            Uses fileparameters to match files and group them into epochs.
            Hidden files (starting with '.') are excluded.
        """
        if self.session is None:
            return []

        if not self.fileparameters or 'filematch' not in self.fileparameters:
            return []

        exp_path = self.session.getpath() if hasattr(self.session, 'getpath') else str(self.session.path)
        filematch_patterns = self.fileparameters['filematch']

        # Find file groups matching patterns
        epochfiles_disk = self._findfilegroups(exp_path, filematch_patterns)

        # Drop hidden files
        filtered_epochs = []
        for epoch_files in epochfiles_disk:
            has_hidden = False
            for filepath in epoch_files:
                filename = os.path.basename(filepath)
                if filename.startswith('.'):
                    has_hidden = True
                    break
            if not has_hidden:
                filtered_epochs.append(epoch_files)

        return filtered_epochs

    def _findfilegroups(self, directory: str, patterns: List[str]) -> List[List[str]]:
        """
        Find groups of files matching patterns.

        Args:
            directory: Directory to search
            patterns: List of file match patterns

        Returns:
            List of file lists (one per group/epoch)

        Notes:
            Patterns can be:
            - Regex patterns: '.*\\.ext$'
            - Exact filenames: 'file.ext'
            - Wildcard patterns: '#.ext1' where # is a wildcard
        """
        import re
        from glob import glob

        # Collect all files recursively
        all_files = []
        for root, dirs, files in os.walk(directory):
            for file in files:
                filepath = os.path.join(root, file)
                all_files.append(filepath)

        # Group files by matching patterns
        if not patterns:
            return []

        # Check if patterns use '#' wildcard
        has_wildcard = any('#' in p for p in patterns)

        if has_wildcard:
            # Complex matching with '#' substitution
            return self._findfilegroups_wildcard(all_files, patterns)
        else:
            # Simple regex matching
            return self._findfilegroups_regex(all_files, patterns)

    def _findfilegroups_regex(self, all_files: List[str], patterns: List[str]) -> List[List[str]]:
        """
        Find file groups using regex patterns.

        Args:
            all_files: All files in directory
            patterns: Regex patterns

        Returns:
            List of file lists
        """
        import re

        # Each pattern defines a separate set of files
        # We return one epoch per unique combination
        epochs = {}

        for filepath in all_files:
            filename = os.path.basename(filepath)

            # Check if this file matches all patterns
            matches_all = True
            for pattern in patterns:
                try:
                    if not re.match(pattern, filename):
                        matches_all = False
                        break
                except re.error:
                    # Not a regex, try exact match
                    if pattern != filename:
                        matches_all = False
                        break

            if matches_all:
                # This file matches - add to epoch
                # For simple regex, each matching file is its own epoch
                # unless patterns are designed to match multiple files
                epoch_key = filepath
                if epoch_key not in epochs:
                    epochs[epoch_key] = []
                epochs[epoch_key].append(filepath)

        return list(epochs.values())

    def _findfilegroups_wildcard(self, all_files: List[str], patterns: List[str]) -> List[List[str]]:
        """
        Find file groups using wildcard '#' patterns.

        Args:
            all_files: All files in directory
            patterns: Patterns with '#' wildcards

        Returns:
            List of file lists (one per unique wildcard value)

        Notes:
            '#' is a wildcard that must be the same value across all patterns.
            Example: patterns = ['#.ext1', 'myfile#.ext2']
            Would match: ['001.ext1', 'myfile001.ext2'] with # = '001'
        """
        import re

        # Build regex patterns where '#' becomes a capture group
        regex_patterns = []
        for pattern in patterns:
            # Escape special regex chars except '#'
            escaped = pattern.replace('\\', '\\\\')
            escaped = escaped.replace('.', '\\.')
            escaped = escaped.replace('*', '\\*')
            escaped = escaped.replace('+', '\\+')
            escaped = escaped.replace('?', '\\?')
            escaped = escaped.replace('(', '\\(')
            escaped = escaped.replace(')', '\\)')
            escaped = escaped.replace('[', '\\[')
            escaped = escaped.replace(']', '\\]')
            escaped = escaped.replace('{', '\\{')
            escaped = escaped.replace('}', '\\}')
            escaped = escaped.replace('^', '\\^')
            escaped = escaped.replace('$', '\\$')
            escaped = escaped.replace('|', '\\|')

            # Replace '#' with capture group
            regex = escaped.replace('#', '(.*?)')
            regex_patterns.append(regex)

        # Find all wildcard values
        wildcard_values = {}  # wildcard_value -> {pattern_idx: filepath}

        for filepath in all_files:
            filename = os.path.basename(filepath)

            # Try to match each pattern and extract wildcard value
            for pattern_idx, regex in enumerate(regex_patterns):
                try:
                    match = re.fullmatch(regex, filename)
                    if match and match.groups():
                        wildcard_value = match.group(1)

                        # Store this file under this wildcard value
                        if wildcard_value not in wildcard_values:
                            wildcard_values[wildcard_value] = {}

                        wildcard_values[wildcard_value][pattern_idx] = filepath
                except re.error:
                    continue

        # Group files with same wildcard value
        epochs = []
        for wildcard_value, pattern_files in wildcard_values.items():
            # Check if this wildcard value matched all patterns
            if len(pattern_files) == len(patterns):
                # Complete match - all patterns matched with same wildcard
                epoch_files = [pattern_files[i] for i in range(len(patterns))]
                epochs.append(epoch_files)

        return epochs

    def getepochfiles(self, epoch_number_or_id: Any) -> List[str]:
        """
        Get the list of files for a given epoch.

        Args:
            epoch_number_or_id: Epoch number (int) or epoch ID (str)

        Returns:
            List of file paths for this epoch

        Notes:
            Uses cached values if available.
        """
        # Check if it's a number or ID
        if isinstance(epoch_number_or_id, str):
            # It's an epoch ID - need to find the number
            et, _ = self.epochtable()
            for i, e in enumerate(et):
                if e.get('epoch_id') == epoch_number_or_id:
                    epoch_number = i + 1
                    break
            else:
                raise ValueError(f"Epoch ID {epoch_number_or_id} not found")
        else:
            epoch_number = int(epoch_number_or_id)

        # Check cache
        if epoch_number in self._cached_epochfilenames:
            return self._cached_epochfilenames[epoch_number]

        # Get from epoch table
        et, _ = self.epochtable()
        if epoch_number < 1 or epoch_number > len(et):
            raise ValueError(f"Epoch number {epoch_number} out of range")

        epoch_entry = et[epoch_number - 1]
        underlying = epoch_entry.get('underlying_epochs', [])
        if underlying:
            files = underlying[0].get('underlying', [])
        else:
            files = []

        # Cache and return
        self._cached_epochfilenames[epoch_number] = files
        return files

    def getepochfiles_number(self, epoch_number: int) -> List[str]:
        """
        Get files for an epoch by number only.

        Args:
            epoch_number: Epoch number (1-indexed)

        Returns:
            List of file paths
        """
        return self.getepochfiles(epoch_number)

    def epochid(self, epoch_number: int, epochfiles: Optional[List[str]] = None) -> str:
        """
        Get or create the epoch ID for an epoch.

        Args:
            epoch_number: Epoch number
            epochfiles: Optional list of epoch files

        Returns:
            Epoch ID string

        Notes:
            If epoch ID file exists on disk, reads it.
            Otherwise, creates a new ID and saves it.
        """
        if epochfiles is None:
            epochfiles = self.getepochfiles(epoch_number)

        # Check if files are ingested
        if self.isingested(epochfiles):
            return self.ingestedfiles_epochid(epochfiles)

        # Get epoch ID filename
        eidfname = self.epochidfilename(epoch_number, epochfiles)

        # Read existing or create new
        if eidfname and os.path.isfile(eidfname):
            with open(eidfname, 'r') as f:
                eid = f.read().strip()
        else:
            eid = f'epoch_{IDO.unique_id()}'
            if eidfname:
                # Save to file
                try:
                    with open(eidfname, 'w') as f:
                        f.write(eid)
                except:
                    pass  # Silently fail if can't write

        return eid

    def epochidfilename(self, number: int, epochfiles: Optional[List[str]] = None) -> str:
        """
        Return the file path for the epoch ID file.

        Args:
            number: Epoch number
            epochfiles: Optional list of epoch files

        Returns:
            Path to epoch ID file

        Notes:
            Epoch ID stored as hidden file: .FILENAME.HASH.epochid.ndi
        """
        fmstr = self.filematch_hashstring()

        if epochfiles is None:
            epochfiles = self.getepochfiles_number(number)

        if not epochfiles:
            raise ValueError(f"No files in epoch number {number}")

        if self.isingested(epochfiles):
            return ''

        # Use first file to determine location
        first_file = epochfiles[0]
        parent_dir = os.path.dirname(first_file)
        filename = os.path.basename(first_file)

        return os.path.join(parent_dir, f'.{filename}.{fmstr}.epochid.ndi')

    def epochprobemapfilename(self, number: int) -> str:
        """
        Return the filename for the epoch probe map file.

        Args:
            number: Epoch number

        Returns:
            Path to epoch probe map file

        Notes:
            Uses epochprobemap_fileparameters if set, otherwise default.
        """
        # Default
        ecfname = self.defaultepochprobemapfilename(number)

        # Check if we need to use a different name based on parameters
        if self.epochprobemap_fileparameters:
            # TODO: Implement file matching logic
            pass

        return ecfname

    def defaultepochprobemapfilename(self, number: int) -> str:
        """
        Return the default epoch probe map filename.

        Args:
            number: Epoch number

        Returns:
            Path to default epoch probe map file

        Notes:
            Stored as hidden file: .FILENAME.HASH.epochprobemap.ndi
        """
        fmstr = self.filematch_hashstring()
        epochfiles = self.getepochfiles_number(number)

        if not epochfiles:
            raise ValueError(f"No files in epoch number {number}")

        if self.isingested(epochfiles):
            return ''

        first_file = epochfiles[0]
        parent_dir = os.path.dirname(first_file)
        filename = os.path.basename(first_file)

        return os.path.join(parent_dir, f'.{filename}.{fmstr}.epochprobemap.ndi')

    def getepochprobemap(self, N: int, epochfiles: Optional[List[str]] = None) -> Any:
        """
        Get the epoch probe map for an epoch.

        Args:
            N: Epoch number
            epochfiles: Optional list of epoch files

        Returns:
            Epoch probe map object or None

        Notes:
            Loads from ingested document or from file on disk.
        """
        if epochfiles is None:
            epochfiles = self.getepochfiles(N)

        # Check if files are ingested
        if self.isingested(epochfiles):
            # Load from ingested document
            d = self.getepochingesteddoc(epochfiles)
            if d:
                epm_data = d.document_properties.get('epochfiles_ingested', {}).get('epochprobemap', None)
                if epm_data:
                    # Deserialize epoch probe map using epochprobemap_class
                    # TODO: Dynamically load class and deserialize
                    # For now, return the raw data
                    return epm_data
            return None
        else:
            # Load from file on disk
            epm_filename = self.epochprobemapfilename(N)

            if epm_filename and os.path.isfile(epm_filename):
                try:
                    with open(epm_filename, 'r') as f:
                        epm_data = json.load(f)
                    # TODO: Deserialize using epochprobemap_class
                    return epm_data
                except:
                    return None
            else:
                return None

    def getepochingesteddoc(self, epochfiles: List[str]) -> Optional[Document]:
        """
        Get ingested epoch document if it exists.

        Args:
            epochfiles: List of epoch files

        Returns:
            Document if exists, None otherwise
        """
        if not self.isingested(epochfiles):
            return None

        if self.session is None:
            return None

        epochid = self.ingestedfiles_epochid(epochfiles)

        try:
            epoch_query = (
                Query('', 'isa', 'epochfiles_ingested') &
                Query('', 'depends_on', 'filenavigator_id', self.id()) &
                Query('base.session_id', 'exact_string', self.session.id()) &
                Query('epochfiles_ingested.epoch_id', 'exact_string', epochid)
            )
            docs = self.session.database_search(epoch_query)
            if len(docs) == 1:
                return docs[0]
            elif len(docs) > 1:
                raise ValueError(f"Expected 1 file navigator ingested document, but found {len(docs)}.")
        except:
            pass

        return None

    def filematch_hashstring(self) -> str:
        """
        Generate a hash string from file parameters.

        Returns:
            Hash string for identifying files

        Notes:
            Used to create unique filenames for metadata.
        """
        # Simple hash based on fileparameters
        import hashlib
        param_str = str(self.fileparameters)
        return hashlib.md5(param_str.encode()).hexdigest()[:8]

    # EpochSet methods

    def epochclock(self, epoch_number: int) -> List[Any]:
        """
        Return clock types for this epoch.

        Args:
            epoch_number: Epoch number

        Returns:
            List of ClockType objects

        Notes:
            File navigator doesn't keep time, returns 'no_time'.
        """
        from ..time import ClockType
        return [ClockType('no_time')]

    def t0_t1(self, epoch_number: int) -> List[List[float]]:
        """
        Return beginning and end times for the epoch.

        Args:
            epoch_number: Epoch number

        Returns:
            List of [t0, t1] pairs

        Notes:
            File navigator doesn't keep time, returns [[NaN, NaN]].
        """
        return [[float('nan'), float('nan')]]

    def getcache(self) -> Tuple[Optional[Any], Optional[str]]:
        """
        Get the cache and key for this file navigator.

        Returns:
            Tuple of (cache, key)
        """
        cache = None
        key = None

        if self.session is not None and hasattr(self.session, 'cache'):
            cache = self.session.cache
            key = f'filenavigator_{self.id()}'

        return cache, key

    # Static utility methods

    @staticmethod
    def isingested(epochfiles: List[str]) -> bool:
        """
        Check if epoch files are ingested (stored in database).

        Args:
            epochfiles: List of file paths

        Returns:
            True if files are ingested, False if on disk

        Notes:
            Ingested files have special format starting with 'epochid://'.
        """
        if not epochfiles:
            return False

        if len(epochfiles) >= 1:
            return epochfiles[0].startswith('epochid://')

        return False

    @staticmethod
    def ingestedfiles_epochid(epochfiles: List[str]) -> str:
        """
        Extract epoch ID from ingested file paths.

        Args:
            epochfiles: List of ingested file paths

        Returns:
            Epoch ID string

        Notes:
            Ingested files have format: 'epochid://EPOCHID'
        """
        if not Navigator.isingested(epochfiles):
            raise ValueError("This function is only applicable to ingested epochfiles.")

        # First file has format 'epochid://EPOCHID'
        epoch_id = epochfiles[0][len('epochid://'):]
        return epoch_id

    # Document service methods

    def newdocument(self) -> Document:
        """
        Create an NDI document for this file navigator.

        Returns:
            Document object
        """
        doc = Document('filenavigator',
                      filenavigator={
                          'fileparameters': str(self.fileparameters),
                          'epochprobemap_class': self.epochprobemap_class,
                          'epochprobemap_fileparameters': str(self.epochprobemap_fileparameters)
                      })

        doc.document_properties['base']['id'] = self.id()
        if self.session is not None:
            doc.document_properties['base']['session_id'] = self.session.id()

        return doc

    def searchquery(self) -> Query:
        """
        Create a search query for this file navigator.

        Returns:
            Query object
        """
        q = Query('base.id', 'exact_string', self.id())
        if self.session is not None:
            q = q & Query('base.session_id', 'exact_string', self.session.id())
        return q

    def __eq__(self, other: 'Navigator') -> bool:
        """Check equality of two navigators."""
        if not isinstance(other, Navigator):
            return False

        return (self.session == other.session and
                self.fileparameters == other.fileparameters and
                self.epochprobemap_class == other.epochprobemap_class and
                self.epochprobemap_fileparameters == other.epochprobemap_fileparameters)

    def __repr__(self) -> str:
        """String representation."""
        return f"Navigator(id='{self.id()}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
