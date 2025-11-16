"""
NDI Subject Maker - Extract and create subject documents from tabular data.

This module provides SubjectMaker class for extracting unique subject
information from metadata tables and creating NDI subject documents.
"""

from typing import List, Dict, Any, Optional, Tuple
import logging
import pandas as pd
import numpy as np


class SubjectMaker:
    """
    A helper class to extract subject information from tables and manage NDI subject documents.

    Provides methods to facilitate the extraction of unique subject
    information based on metadata in tables, and to manage NDI subject
    documents (e.g., creation, addition to sessions, deletion).

    This class acts as an orchestrator for a common NDI setup workflow:
    1. Read a metadata table (e.g., from a spreadsheet).
    2. Use a lab-specific 'creator' object to interpret the table and extract subject details.
    3. Generate NDI documents for each unique subject and their related metadata.
    4. Add these new documents to the appropriate NDI session database.

    Example:
        >>> from ndi.setup.makers import SubjectMaker
        >>> from ndi.setup.creators import SubjectInformationCreator
        >>> import pandas as pd
        >>>
        >>> # Define a simple creator
        >>> class SimpleCreator(SubjectInformationCreator):
        ...     def create(self, table_row):
        ...         subject_id = table_row['SubjectID'].values[0]
        ...         return subject_id, None, 'mouse', 'male'
        >>>
        >>> # Create table with subject data
        >>> data = {
        ...     'SubjectID': ['M001', 'M001', 'M002'],
        ...     'sessionID': ['s1', 's1', 's1']
        ... }
        >>> table = pd.DataFrame(data)
        >>>
        >>> # Extract subject info
        >>> maker = SubjectMaker()
        >>> creator = SimpleCreator()
        >>> subject_info, all_names = maker.get_subject_info_from_table(table, creator)
        >>> print(f"Found {len(subject_info['subject_name'])} unique subjects")
        Found 2 unique subjects
    """

    def __init__(self):
        """
        Construct an instance of SubjectMaker.

        Creates a SubjectMaker object with no arguments. This object is
        ready to use its methods for extracting and managing subject information.
        """
        pass

    def add_subjects_from_table(self,
                               session: Any,
                               data_table: pd.DataFrame,
                               subject_info_creator: Any) -> Tuple[Dict[str, List], List[str], List[str]]:
        """
        Process a table to create and add subjects to a session.

        This method provides a high-level workflow that encapsulates the entire process of
        importing subjects from a metadata table into an NDI session. It handles extracting
        unique subject information, creating the corresponding NDI documents, and adding
        those documents to the session's database.

        Args:
            session: The NDI session object where the subjects will be added.
            data_table: A DataFrame containing metadata to define subjects.
            subject_info_creator: An object that encapsulates the lab-specific rules
                                 for converting a table row to subject information.
                                 Must inherit from SubjectInformationCreator.

        Returns:
            A tuple containing:
                - subject_info (dict): Structure containing data for unique, valid subjects
                                      that were added. See get_subject_info_from_table for
                                      detailed field descriptions.
                - all_subject_names_from_table (list): List with one entry per row of
                                                       data_table containing subject names or None.
                - subject_doc_ids (list): List with one entry per row containing
                                         subject document IDs.

        Example:
            >>> maker = SubjectMaker()
            >>> subject_info, all_names, doc_ids = maker.add_subjects_from_table(
            ...     session, data_table, creator
            ... )
        """
        # Add sessionID column
        data_table = data_table.copy()
        data_table['sessionID'] = session.id()

        logging.info('Extracting unique subject information from the table...')

        # 1. Extract unique subject information using the creator
        subject_info, all_subject_names_from_table = self.get_subject_info_from_table(
            data_table, subject_info_creator
        )

        if not subject_info['subject_name']:
            logging.info('No valid subjects found to add.')
            return subject_info, all_subject_names_from_table, []

        logging.info(f"Found {len(subject_info['subject_name'])} unique subjects to process.")

        # 2. Create NDI documents for the unique subjects
        logging.info('Creating NDI documents for subjects...')
        sub_doc_struct = self.make_subject_documents(subject_info)

        # 3. Add the new subject documents to the session
        logging.info('Adding new subject documents to the session database...')
        self.add_subjects_to_sessions([session], sub_doc_struct['documents'])

        # 4. Return subject document IDs
        subject_doc_ids = [docs[0].id() for docs in sub_doc_struct['documents']]

        return subject_info, all_subject_names_from_table, subject_doc_ids

    def get_subject_info_from_table(self,
                                   data_table: pd.DataFrame,
                                   subject_info_creator: Any) -> Tuple[Dict[str, List], List]:
        """
        Extract unique subject information from a table using a creator object.

        This is the core data extraction and transformation method. It processes each row
        of an input data_table using a user-provided "creator" object. This creator
        contains the lab-specific logic to interpret the columns of the table.

        The method returns two main outputs:
        1. subject_info: A clean, de-duplicated structure of all *valid* subjects found
           in the table. A subject is considered valid if the creator returns a non-empty
           name and the table row has a valid session ID.
        2. all_subject_names_from_table: A list that has a 1-to-1 mapping with the rows
           of the input data_table. It contains the raw output from the creator for every
           row, useful for later associating data back to the original table.

        Args:
            data_table: A DataFrame containing metadata to define subjects.
                       MUST contain a column named 'sessionID'.
            subject_info_creator: An object that inherits from SubjectInformationCreator
                                 and implements the create() method.

        Returns:
            A tuple containing:
                - subject_info (dict): Dictionary with the following keys (all lists/arrays):
                    - subject_name: Unique subject identifiers
                    - strain: Corresponding strain objects (or None)
                    - species: Corresponding species objects (or None)
                    - biological_sex: Corresponding biological sex data (or None)
                    - table_row_index: Row index from original data_table where this
                                      unique subject's information was first found
                    - session_id: Session identifier associated with the row
                - all_subject_names_from_table (list): List with one entry per row of
                                                       data_table containing subject names or None.

        Raises:
            ValueError: If data_table is empty or lacks 'sessionID' column.

        Example:
            >>> maker = SubjectMaker()
            >>> subject_info, all_names = maker.get_subject_info_from_table(
            ...     data_table, creator
            ... )
            >>> print(f"Unique subjects: {subject_info['subject_name']}")
        """
        # Validate inputs
        if data_table.empty:
            raise ValueError("data_table must be non-empty")
        if 'sessionID' not in data_table.columns:
            raise ValueError("data_table must contain 'sessionID' column")

        num_rows = len(data_table)
        all_subject_names = [None] * num_rows
        all_strains = [None] * num_rows
        all_species = [None] * num_rows
        all_biological_sex = [None] * num_rows
        all_session_ids = [''] * num_rows

        raw_session_ids = data_table['sessionID'].values

        # Process each row using the creator
        for i in range(num_rows):
            current_row = data_table.iloc[[i]]  # Keep as single-row DataFrame

            try:
                local_id, strain_obj, species_obj, sex_obj = subject_info_creator.create(current_row)
                all_subject_names[i] = local_id
                all_strains[i] = strain_obj
                all_species[i] = species_obj
                all_biological_sex[i] = sex_obj

                # Get session ID if valid
                session_id_value = raw_session_ids[i]
                if session_id_value is not None and not (isinstance(session_id_value, float) and np.isnan(session_id_value)):
                    all_session_ids[i] = str(session_id_value)

            except Exception as e:
                logging.warning(f"Error processing row {i}: {e}")
                all_subject_names[i] = None

        # Find unique, valid subjects
        seen_subjects = {}
        unique_subject_names = []
        unique_strains = []
        unique_species = []
        unique_biological_sex = []
        unique_table_row_indices = []
        unique_session_ids = []

        for i in range(num_rows):
            subject_name = all_subject_names[i]
            session_id = all_session_ids[i]

            # Check if this is a valid subject (non-empty name and valid session)
            is_valid_name = (subject_name is not None and
                           subject_name != '' and
                           not (isinstance(subject_name, float) and np.isnan(subject_name)))
            is_valid_session = session_id != ''

            if is_valid_name and is_valid_session:
                if subject_name not in seen_subjects:
                    # First occurrence of this subject
                    seen_subjects[subject_name] = len(unique_subject_names)
                    unique_subject_names.append(subject_name)
                    unique_strains.append(all_strains[i])
                    unique_species.append(all_species[i])
                    unique_biological_sex.append(all_biological_sex[i])
                    unique_table_row_indices.append(i)
                    unique_session_ids.append(session_id)

        # Build result structure
        subject_info = {
            'subject_name': unique_subject_names,
            'strain': unique_strains,
            'species': unique_species,
            'biological_sex': unique_biological_sex,
            'table_row_index': unique_table_row_indices,
            'session_id': unique_session_ids,
        }

        return subject_info, all_subject_names

    def make_subject_documents(self, subject_info: Dict[str, List]) -> Dict[str, List]:
        """
        Create NDI subject documents from subject information.

        Args:
            subject_info: Dictionary containing subject information with keys:
                         subject_name, strain, species, biological_sex, session_id.

        Returns:
            Dictionary with key 'documents' containing list of document lists.
            Each inner list contains documents for one subject.

        Note:
            This is a simplified implementation. Full openMINDS integration
            is deferred to a later phase.
        """
        from ...document import Document

        documents = []

        for i in range(len(subject_info['subject_name'])):
            subject_name = subject_info['subject_name'][i]
            strain = subject_info['strain'][i]
            species = subject_info['species'][i]
            biological_sex = subject_info['biological_sex'][i]
            session_id = subject_info['session_id'][i]

            # Create subject document
            # TODO: Full openMINDS integration - create proper subject document type
            doc_data = {
                'name': subject_name,
                'species': species,
                'strain': strain,
                'biological_sex': biological_sex,
            }

            # Create a simple subject document
            # Note: In full implementation, this would create openMINDS-compliant documents
            doc = Document('ndi_document_subject', f'subject_{subject_name}', doc_data)

            documents.append([doc])  # Wrap in list to match MATLAB structure

        return {'documents': documents}

    def add_subjects_to_sessions(self,
                                sessions: List[Any],
                                subject_documents: List[List[Any]]) -> None:
        """
        Add subject documents to session databases.

        Args:
            sessions: List of NDI session objects.
            subject_documents: List of document lists to add to sessions.

        Note:
            Currently adds all subjects to all sessions. In full implementation,
            this would map subjects to appropriate sessions based on session_id.
        """
        for session in sessions:
            for doc_list in subject_documents:
                for doc in doc_list:
                    session.database_add(doc)

        logging.info(f"Added {len(subject_documents)} subject(s) to {len(sessions)} session(s)")

    def __repr__(self) -> str:
        """String representation of SubjectMaker."""
        return "SubjectMaker()"
