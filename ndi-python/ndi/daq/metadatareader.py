"""
NDI DAQ MetadataReader - Read metadata parameters from epoch files.

This module provides the MetadataReader class for extracting metadata
such as stimulus parameters from data acquisition files.
"""

from typing import Optional, List, Dict, Any
import re
import os
from ..ido import IDO
from ..document import Document
from ..query import Query


class MetadataReader(IDO):
    """
    MetadataReader - Read metadata parameters from epoch files.

    The MetadataReader class reads metadata related to data acquisition,
    such as stimulus parameter information from tab-separated-value files
    or other data formats.

    Attributes:
        tab_separated_file_parameter: Regular expression to search epochfiles
            for a tab-separated-value file describing stimulus parameters

    Examples:
        >>> # Create metadata reader for stimulus files
        >>> reader = MetadataReader(r'.*_stim\.txt$')
        >>> # Read metadata from epoch files
        >>> params = reader.readmetadata(epochfiles)
    """

    def __init__(self, *args):
        """
        Create a MetadataReader.

        Two forms:
        1. MetadataReader() - Empty reader
        2. MetadataReader(tsv_file_regex) - Reader with TSV file pattern
        3. MetadataReader(session, document) - Load from document

        Args (Form 1):
            No arguments

        Args (Form 2):
            tsv_file_regex: Regular expression for finding metadata files

        Args (Form 3):
            session: NDI Session object
            document: NDI Document object
        """
        super().__init__()

        # Initialize properties
        self.tab_separated_file_parameter = ''

        if len(args) == 0:
            # Form 1: Empty
            pass
        elif len(args) == 1:
            # Form 2: TSV file regex
            self.tab_separated_file_parameter = args[0]
        elif len(args) == 2:
            # Form 3: Load from document
            session, doc = args
            if isinstance(doc, Document):
                self.identifier = doc.document_properties.get('base', {}).get('id', '')
                if 'daqmetadatareader' in doc.document_properties:
                    self.tab_separated_file_parameter = doc.document_properties['daqmetadatareader'].get(
                        'tab_separated_file_parameter', ''
                    )

    def readmetadata(self, epochfiles: List[str]) -> List[Dict[str, Any]]:
        """
        Read metadata parameters from epoch files.

        Args:
            epochfiles: List of file paths for this epoch

        Returns:
            List of parameter dictionaries

        Notes:
            If tab_separated_file_parameter is set, searches epochfiles
            for files matching the regex pattern and reads metadata
            from the matching file.

            TSV file format:
            STIMID<tab>PARAMETER1<tab>PARAMETER2<tab>PARAMETER3 (etc)
            1<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc)
            2<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc)

            Example:
            stimid<tab>substance1<tab>substance1_concentration
            1<tab>Sodium chloride<tab>30e-3
            2<tab>Sodium chloride<tab>300e-3
            3<tab>Quinine<tab>30e-6
        """
        parameters = []

        if not self.tab_separated_file_parameter:
            return parameters

        # Find files matching the regex
        matching_files = []
        for filepath in epochfiles:
            if re.search(self.tab_separated_file_parameter, filepath, re.IGNORECASE):
                matching_files.append(filepath)

        if len(matching_files) > 1:
            raise ValueError(
                f"More than one epochfile matches regular expression '{self.tab_separated_file_parameter}'; "
                f"epochfiles were {epochfiles}"
            )
        elif len(matching_files) == 0:
            raise ValueError(
                f"No epochfiles match regular expression '{self.tab_separated_file_parameter}'; "
                f"epochfiles were {epochfiles}"
            )
        else:
            if not os.path.isfile(matching_files[0]):
                raise ValueError(f"No such file {matching_files[0]}")

            parameters = self.readmetadatafromfile(matching_files[0])

        return parameters

    def readmetadata_ingested(self, epochfiles: List[str], session: Any) -> List[Dict[str, Any]]:
        """
        Read metadata parameters from an ingested session database.

        Args:
            epochfiles: List of file paths for this epoch
            session: NDI Session object

        Returns:
            List of parameter dictionaries

        Notes:
            Reads metadata from ingested documents in the database.
        """
        parameters = []

        d = self.get_ingested_document(epochfiles, session)
        if d is not None:
            # TODO: Implement metadata decompression when compression module ready
            # For now, return empty
            # [tname, tname_without_ext] = ndi.database.fun.copydocfile2temp(d, session, 'data.bin', '.nbf.tgz')
            # parameters = ndi.compress.expand_metadata(tname_without_ext)
            pass

        return parameters

    def readmetadatafromfile(self, filepath: str) -> List[Dict[str, Any]]:
        """
        Read metadata parameters from a file.

        Args:
            filepath: Path to metadata file

        Returns:
            List of parameter dictionaries

        Notes:
            Reads tab-separated-value files with header row.
            First column should be 'stimid' or similar identifier.
        """
        parameters = []

        if not os.path.isfile(filepath):
            return parameters

        try:
            with open(filepath, 'r') as f:
                lines = f.readlines()

            if len(lines) < 2:
                return parameters

            # Parse header line
            header = lines[0].strip().split('\t')

            # Parse data lines
            for line in lines[1:]:
                line = line.strip()
                if not line:
                    continue

                values = line.split('\t')
                if len(values) != len(header):
                    continue

                # Create parameter dict
                param = {}
                for i, key in enumerate(header):
                    # Try to convert to number if possible
                    try:
                        value = float(values[i])
                        # If it's actually an int, convert it
                        if value.is_integer():
                            value = int(value)
                    except ValueError:
                        value = values[i]

                    param[key] = value

                parameters.append(param)

        except Exception as e:
            # If reading fails, return empty list
            pass

        return parameters

    def ingest_epochfiles(self, epochfiles: List[str], epoch_id: str) -> Document:
        """
        Create a document describing metadata for ingested files.

        Args:
            epochfiles: List of file paths
            epoch_id: Epoch identifier

        Returns:
            Document object (not added to database)

        Notes:
            Creates an ndi.document of type 'daqmetadatareader_epochdata_ingested'.
            The document is not automatically added to the database.
        """
        epochid_struct = {'epochid': epoch_id}

        d = Document('daqmetadatareader_epochdata_ingested', epochid=epochid_struct)
        d = d.set_dependency_value('daqmetadatareader_id', self.id())

        # Read metadata
        parameters = self.readmetadata(epochfiles)

        # TODO: Compress metadata when compression module ready
        # For now, just store as JSON
        # metadatafile = ndi.file.temp_name()
        # ratio = ndi.compress.compress_metadata(parameters, metadatafile)
        # d = d.add_file('data.bin', f'{metadatafile}.nbf.tgz')

        return d

    def get_ingested_document(self, epochfiles: List[str], session: Any) -> Optional[Document]:
        """
        Get an ingested document for a set of epochfiles.

        Args:
            epochfiles: List of file paths
            session: NDI Session object

        Returns:
            Document if found, None otherwise
        """
        from ..file import Navigator

        epochid = None

        try:
            epochid = Navigator.ingestedfiles_epochid(epochfiles)
        except:
            return None

        q = (
            Query('', 'depends_on', 'daqmetadatareader_id', self.id()) &
            Query('epochid.epochid', 'exact_string', epochid)
        )

        docs = session.database_search(q)
        if len(docs) == 1:
            return docs[0]

        return None

    def __eq__(self, other: 'MetadataReader') -> bool:
        """
        Check equality of two MetadataReader objects.

        Args:
            other: Another MetadataReader object

        Returns:
            True if same class and same properties
        """
        if not isinstance(other, type(self)):
            return False

        return self.tab_separated_file_parameter == other.tab_separated_file_parameter

    # Document service methods

    def newdocument(self) -> Document:
        """
        Create a new ndi.document for this MetadataReader.

        Returns:
            Document object
        """
        from ..session import Session

        doc = Document(
            'daqmetadatareader',
            **{
                'daqmetadatareader.ndi_daqmetadatareader_class': type(self).__name__,
                'daqmetadatareader.tab_separated_file_parameter': self.tab_separated_file_parameter,
                'base.id': self.id(),
                'base.session_id': Session.empty_id()
            }
        )

        return doc

    def searchquery(self) -> Query:
        """
        Create a search query for this MetadataReader.

        Returns:
            Query object
        """
        return Query('base.id', 'exact_string', self.id())

    def __repr__(self) -> str:
        """String representation."""
        return f"MetadataReader(pattern='{self.tab_separated_file_parameter}')"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()
