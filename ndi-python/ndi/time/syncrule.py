"""
NDI SyncRule - Base class for managing synchronization between epochs.
"""

from typing import List, Optional, Tuple, Dict, Any
from abc import ABC, abstractmethod
from pathlib import Path

from ..ido import IDO
from ..document import Document
from ..query import Query
from .clocktype import ClockType
from .timemapping import TimeMapping


class SyncRule(IDO, ABC):
    """
    NDI SyncRule - base class for synchronization rules.
    """

    def __init__(self, parameters: Optional[Dict[str, Any]] = None,
                 session=None, document: Optional[Document] = None):
        super().__init__()
        if session is not None and document is not None:
            parameters = document.document_properties.get('syncrule', {}).get('parameters', {})
            self.identifier = document.document_properties['base']['id']
        elif parameters is None:
            parameters = {}
        self.parameters = {}
        self.set_parameters(parameters)

    def set_parameters(self, parameters: Dict[str, Any]) -> 'SyncRule':
        is_valid, msg = self.is_valid_parameters(parameters)
        if not is_valid:
            raise ValueError(f"Could not set parameters: {msg}")
        self.parameters = parameters
        return self

    def is_valid_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        return True, ""

    def __eq__(self, other: 'SyncRule') -> bool:
        if not isinstance(other, SyncRule):
            return False
        return self.parameters == other.parameters

    def eligible_clocks(self) -> List[ClockType]:
        return []

    def ineligible_clocks(self) -> List[ClockType]:
        return [ClockType('no_time')]

    def eligible_epochsets(self) -> List[str]:
        return []

    def ineligible_epochsets(self) -> List[str]:
        return []

    @abstractmethod
    def apply(self, epochnode_a: Dict[str, Any], epochnode_b: Dict[str, Any]) -> Tuple[Optional[float], Optional[TimeMapping]]:
        return None, None

    def newdocument(self) -> Document:
        doc = Document('syncrule',
                      syncrule_ndi_syncrule_class=self.__class__.__module__ + '.' + self.__class__.__name__,
                      syncrule_parameters=self.parameters)
        doc.document_properties['base']['id'] = self.id()
        doc.document_properties['base']['session_id'] = ''
        return doc

    def searchquery(self) -> Query:
        return Query('base.id', 'exact_string', self.id())

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}(parameters={self.parameters})"

    def __str__(self) -> str:
        return self.__repr__()


class FileMatchSyncRule(SyncRule):
    """FileMatch SyncRule - synchronizes epochs with common underlying files."""

    def __init__(self, parameters: Optional[Dict[str, Any]] = None, session=None, document=None):
        if parameters is None:
            parameters = {'number_fullpath_matches': 2}
        super().__init__(parameters, session, document)

    def is_valid_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        if 'number_fullpath_matches' not in parameters:
            return False, "Missing required field 'number_fullpath_matches'"
        if not isinstance(parameters['number_fullpath_matches'], (int, float)):
            return False, "number_fullpath_matches must be a number"
        return True, ""

    def eligible_epochsets(self) -> List[str]:
        return ['ndi.daq.system']

    def ineligible_epochsets(self) -> List[str]:
        base_ineligible = super().ineligible_epochsets()
        return base_ineligible + ['ndi.epoch.epochset', 'ndi.epoch.epochset.param', 'ndi.file.navigator']

    def apply(self, epochnode_a: Dict[str, Any], epochnode_b: Dict[str, Any]) -> Tuple[Optional[float], Optional[TimeMapping]]:
        cost, mapping = None, None
        if 'objectclass' not in epochnode_a or 'objectclass' not in epochnode_b:
            return cost, mapping
        if 'underlying_epochs' not in epochnode_a or 'underlying_epochs' not in epochnode_b:
            return cost, mapping
        underlying_a = epochnode_a.get('underlying_epochs', {})
        underlying_b = epochnode_b.get('underlying_epochs', {})
        if not underlying_a or not underlying_b:
            return cost, mapping
        files_a = underlying_a.get('underlying', [])
        files_b = underlying_b.get('underlying', [])
        if not files_a or not files_b:
            return cost, mapping
        common = set(files_a) & set(files_b)
        if len(common) >= self.parameters['number_fullpath_matches']:
            cost = 1.0
            mapping = TimeMapping('linear', [1.0, 0.0])
        return cost, mapping


class FileFindSyncRule(SyncRule):
    """FileFind SyncRule - synchronizes epochs using a synchronization file."""

    def __init__(self, parameters: Optional[Dict[str, Any]] = None, session=None, document=None):
        if parameters is None:
            parameters = {'number_fullpath_matches': 1, 'syncfilename': 'syncfile.txt',
                         'daqsystem1': 'mydaq1', 'daqsystem2': 'mydaq2'}
        super().__init__(parameters, session, document)

    def is_valid_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        required = ['number_fullpath_matches', 'syncfilename', 'daqsystem1', 'daqsystem2']
        for field in required:
            if field not in parameters:
                return False, f"Missing required field '{field}'"
        if not isinstance(parameters['number_fullpath_matches'], (int, float)):
            return False, "number_fullpath_matches must be a number"
        if not isinstance(parameters['syncfilename'], str):
            return False, "syncfilename must be a string"
        if not isinstance(parameters['daqsystem1'], str):
            return False, "daqsystem1 must be a string"
        if not isinstance(parameters['daqsystem2'], str):
            return False, "daqsystem2 must be a string"
        return True, ""

    def eligible_epochsets(self) -> List[str]:
        return ['ndi.daq.system']

    def ineligible_epochsets(self) -> List[str]:
        base_ineligible = super().ineligible_epochsets()
        return base_ineligible + ['ndi.epoch.epochset', 'ndi.epoch.epochset.param', 'ndi.file.navigator']

    def apply(self, epochnode_a: Dict[str, Any], epochnode_b: Dict[str, Any]) -> Tuple[Optional[float], Optional[TimeMapping]]:
        cost, mapping = None, None
        forward = (epochnode_a.get('objectname') == self.parameters['daqsystem1'] and
                  epochnode_b.get('objectname') == self.parameters['daqsystem2'])
        backward = (epochnode_b.get('objectname') == self.parameters['daqsystem1'] and
                   epochnode_a.get('objectname') == self.parameters['daqsystem2'])
        if not forward and not backward:
            return cost, mapping
        if 'underlying_epochs' not in epochnode_a or 'underlying_epochs' not in epochnode_b:
            return cost, mapping
        underlying_a = epochnode_a.get('underlying_epochs', {})
        underlying_b = epochnode_b.get('underlying_epochs', {})
        if not underlying_a or not underlying_b:
            return cost, mapping
        files_a = underlying_a.get('underlying', [])
        files_b = underlying_b.get('underlying', [])
        if not files_a or not files_b:
            return cost, mapping
        common = set(files_a) & set(files_b)
        if len(common) < self.parameters['number_fullpath_matches']:
            return cost, mapping
        cost = 1.0
        if forward:
            for filepath in files_a:
                path = Path(filepath)
                if path.name == self.parameters['syncfilename']:
                    try:
                        with open(filepath, 'r') as f:
                            lines = f.readlines()
                            shift = float(lines[0].strip())
                            scale = float(lines[1].strip())
                        mapping = TimeMapping('linear', [scale, shift])
                        return cost, mapping
                    except (IOError, ValueError) as e:
                        raise ValueError(f"Error reading sync file {filepath}: {e}")
            raise FileNotFoundError(f"No file matched {self.parameters['syncfilename']}")
        if backward:
            for filepath in files_b:
                path = Path(filepath)
                if path.name == self.parameters['syncfilename']:
                    try:
                        with open(filepath, 'r') as f:
                            lines = f.readlines()
                            shift = float(lines[0].strip())
                            scale = float(lines[1].strip())
                        shift_reverse = -shift / scale
                        scale_reverse = 1.0 / scale
                        mapping = TimeMapping('linear', [scale_reverse, shift_reverse])
                        return cost, mapping
                    except (IOError, ValueError) as e:
                        raise ValueError(f"Error reading sync file {filepath}: {e}")
            raise FileNotFoundError(f"No file matched {self.parameters['syncfilename']}")
        return cost, mapping


class CommonTriggersSyncRule(SyncRule):
    """CommonTriggers SyncRule - synchronizes epochs with common trigger files."""

    def __init__(self, parameters: Optional[Dict[str, Any]] = None, session=None, document=None):
        if parameters is None:
            parameters = {'number_fullpath_matches': 2}
        super().__init__(parameters, session, document)

    def is_valid_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        if 'number_fullpath_matches' not in parameters:
            return False, "Missing required field 'number_fullpath_matches'"
        if not isinstance(parameters['number_fullpath_matches'], (int, float)):
            return False, "number_fullpath_matches must be a number"
        return True, ""

    def eligible_epochsets(self) -> List[str]:
        return ['ndi.daq.system']

    def ineligible_epochsets(self) -> List[str]:
        base_ineligible = super().ineligible_epochsets()
        return base_ineligible + ['ndi.epoch.epochset', 'ndi.epoch.epochset.param', 'ndi.file.navigator']

    def apply(self, epochnode_a: Dict[str, Any], epochnode_b: Dict[str, Any]) -> Tuple[Optional[float], Optional[TimeMapping]]:
        cost, mapping = None, None
        if 'objectclass' not in epochnode_a or 'objectclass' not in epochnode_b:
            return cost, mapping
        if 'underlying_epochs' not in epochnode_a or 'underlying_epochs' not in epochnode_b:
            return cost, mapping
        underlying_a = epochnode_a.get('underlying_epochs', {})
        underlying_b = epochnode_b.get('underlying_epochs', {})
        if not underlying_a or not underlying_b:
            return cost, mapping
        files_a = underlying_a.get('underlying', [])
        files_b = underlying_b.get('underlying', [])
        if not files_a or not files_b:
            return cost, mapping
        common = set(files_a) & set(files_b)
        if len(common) >= self.parameters['number_fullpath_matches']:
            cost = 1.0
            mapping = TimeMapping('linear', [1.0, 0.0])
        return cost, mapping
