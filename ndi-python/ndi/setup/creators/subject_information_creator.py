"""
NDI Subject Information Creator - Abstract base class for subject extraction.

This module provides the abstract base class for creating lab-specific subject
information extraction logic from tabular data.
"""

from abc import ABC, abstractmethod
from typing import Tuple, Any, Optional
import pandas as pd


class SubjectInformationCreator(ABC):
    """
    Abstract base class for creating subject information from table rows.

    This class defines the interface for lab-specific subject information
    extraction. Subclasses must implement the create() method to define
    how to interpret table rows and extract subject metadata.

    The creator pattern allows different labs to provide their own logic
    for extracting subject information from metadata tables while maintaining
    a consistent interface.

    Example:
        >>> class MyLabSubjectCreator(SubjectInformationCreator):
        ...     def create(self, table_row):
        ...         # Extract subject ID from 'SubjectID' column
        ...         subject_id = table_row['SubjectID'].values[0]
        ...         if pd.isna(subject_id):
        ...             return None, None, None, None
        ...
        ...         # Extract other metadata
        ...         strain = table_row.get('Strain', None)
        ...         species = table_row.get('Species', None)
        ...         sex = table_row.get('Sex', None)
        ...
        ...         return subject_id, strain, species, sex
        >>>
        >>> creator = MyLabSubjectCreator()
        >>> row = pd.DataFrame({'SubjectID': ['M001'], 'Species': ['mouse']})
        >>> subject_id, strain, species, sex = creator.create(row)
    """

    @abstractmethod
    def create(self,
               table_row: pd.DataFrame) -> Tuple[Optional[str],
                                                  Optional[Any],
                                                  Optional[Any],
                                                  Optional[Any]]:
        """
        Extract subject information from a table row.

        This method must be implemented by subclasses to define lab-specific
        logic for extracting subject information from metadata tables.

        Args:
            table_row: A single-row DataFrame from the metadata table.

        Returns:
            A tuple containing:
                - local_id (str or None): The unique subject identifier/name.
                                         Return None or empty string if row is invalid.
                - strain (object or None): Strain information (e.g., openMINDS Strain object).
                - species (object or None): Species information (e.g., openMINDS Species object).
                - biological_sex (object or None): Biological sex information
                                                   (e.g., openMINDS BiologicalSex object).

        Notes:
            - Return (None, None, None, None) or ('', None, None, None) for invalid rows
            - The local_id should be unique within the experiment/dataset
            - Strain, species, and biological_sex can be simple strings or structured objects
            - The SubjectMaker will handle de-duplication based on local_id
        """
        pass

    def __repr__(self) -> str:
        """String representation of creator."""
        return f"{self.__class__.__name__}()"
