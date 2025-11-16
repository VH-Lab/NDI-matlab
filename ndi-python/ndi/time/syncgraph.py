"""
NDI SyncGraph - manages synchronization graph for time conversion across epochs.

The SyncGraph builds a directed graph of epoch nodes with time mappings between
them, allowing time conversion between different devices and epochs.
"""

from typing import List, Optional, Dict, Any, Tuple
import numpy as np
from pathlib import Path

from ..ido import IDO
from ..document import Document
from ..query import Query
from .syncrule import SyncRule
from .timemapping import TimeMapping
from .clocktype import ClockType


class SyncGraph(IDO):
    """
    NDI SyncGraph - synchronization graph for multi-clock time management.

    The SyncGraph maintains a graph of epoch nodes (from different devices/epochs)
    and manages time mappings between them using SyncRules. It enables time
    conversion across different time bases.

    Attributes:
        session: NDI session object
        rules: List of SyncRule objects to apply when building the graph

    Examples:
        >>> from ndi import Session
        >>> session = Session('/path/to/session')
        >>> graph = SyncGraph(session)
        >>> rule = FileMatchSyncRule({'number_fullpath_matches': 2})
        >>> graph.add_rule(rule)
    """

    def __init__(self, session=None, document: Optional[Document] = None):
        """
        Create a new SyncGraph object.

        Args:
            session: NDI Session object
            document: Optional NDI document for loading existing syncgraph

        Notes:
            If both session and document are provided, the syncgraph is
            loaded from the document (including all syncrules).
        """
        super().__init__()

        self.session = session
        self.rules: List[SyncRule] = []
        self._cached_graphinfo = None

        # Load from document if provided
        if session is not None and document is not None:
            syncgraph_doc, syncrule_docs = self.load_all_syncgraph_docs(session, document.id())
            self.identifier = document.id()
            for syncrule_doc in syncrule_docs:
                # Convert document to syncrule object
                # This would use ndi.database.fun.ndi_document2ndi_object in MATLAB
                # For now, we'll create basic syncrule objects
                # TODO: Implement full document-to-object conversion when documentservice is complete
                pass

    def __eq__(self, other: 'SyncGraph') -> bool:
        """
        Check equality of two syncgraph objects.

        Two syncgraphs are equal if their sessions and all rules are equal.

        Args:
            other: Another SyncGraph to compare

        Returns:
            True if sessions and rules are equal
        """
        if not isinstance(other, SyncGraph):
            return False

        # Compare sessions
        if self.session != other.session:
            return False

        # Compare rules
        if len(self.rules) != len(other.rules):
            return False

        for rule_a, rule_b in zip(self.rules, other.rules):
            if rule_a != rule_b:
                return False

        return True

    def add_rule(self, syncrule: SyncRule) -> 'SyncGraph':
        """
        Add a syncrule to the syncgraph.

        Args:
            syncrule: SyncRule object to add (or list of SyncRule objects)

        Returns:
            Self for chaining

        Notes:
            If the rule is already present (by equality), it won't be added again.
            Adding a rule invalidates the cached graphinfo.
        """
        if not isinstance(syncrule, list):
            syncrule = [syncrule]

        did_add = False
        for rule in syncrule:
            if not isinstance(rule, SyncRule):
                raise TypeError("Input must be a SyncRule object")

            # Check for duplication
            match = False
            for existing_rule in self.rules:
                if existing_rule == rule:
                    match = True
                    break

            if not match:
                did_add = True
                self.rules.append(rule)

        if did_add:
            self.remove_cached_graphinfo()

        return self

    def remove_rule(self, index: int) -> 'SyncGraph':
        """
        Remove a syncrule from the syncgraph.

        Args:
            index: Index of rule to remove (0-based)

        Returns:
            Self for chaining
        """
        if 0 <= index < len(self.rules):
            del self.rules[index]
            self.remove_cached_graphinfo()

        return self

    def graphinfo(self) -> Dict[str, Any]:
        """
        Return the graph information structure.

        Returns:
            Dictionary with fields:
            - nodes: List of epoch nodes
            - G: Adjacency matrix (cost of converting between nodes)
            - mapping: Matrix of TimeMapping objects between nodes
            - diG: Directed graph representation (for path finding)
            - syncRuleIDs: IDs of syncrules used
            - syncRuleG: Which syncrule was used for each edge

        Notes:
            This method uses caching. Call remove_cached_graphinfo() to
            force a rebuild.
        """
        ginfo = self.cached_graphinfo()
        if ginfo is None:
            ginfo = self.buildgraphinfo()
            self.set_cached_graphinfo(ginfo)
        return ginfo

    def buildgraphinfo(self) -> Dict[str, Any]:
        """
        Build graph info from scratch using all devices in the session.

        Returns:
            Graph info dictionary (see graphinfo())

        Notes:
            This method will be fully functional once DAQ system is implemented.
            For now, it returns an empty graph structure.
        """
        ginfo = {
            'nodes': [],
            'G': np.array([]),
            'mapping': [],
            'diG': None,
            'syncRuleIDs': [],
            'syncRuleG': np.array([])
        }

        # Update syncRuleIDs
        for rule in self.rules:
            ginfo['syncRuleIDs'].append(rule.id())

        # TODO: Load DAQ systems and add epochs when DAQ system is implemented
        # For now, return empty graph
        # d = self.session.daqsystem_load('name', '(.*)')
        # for daqsystem in d:
        #     ginfo = self.addepoch(daqsystem, ginfo)

        return ginfo

    def cached_graphinfo(self) -> Optional[Dict[str, Any]]:
        """
        Return the cached graph info if it exists.

        Returns:
            Cached graph info, or None if not cached
        """
        if self._cached_graphinfo is None:
            # Try to load from session cache if available
            cache, key = self.getcache()
            if cache is not None and key is not None:
                entry = cache.lookup(key, 'syncgraph-hash')
                if entry:
                    self._cached_graphinfo = entry[0].data.get('graphinfo')
        return self._cached_graphinfo

    def set_cached_graphinfo(self, ginfo: Dict[str, Any]) -> None:
        """
        Set the cached graph info.

        Args:
            ginfo: Graph info to cache
        """
        self._cached_graphinfo = ginfo

        # Also update session cache if available
        cache, key = self.getcache()
        if cache is not None:
            cache.remove(key, 'syncgraph-hash')
            cache.add(key, 'syncgraph-hash',
                     {'graphinfo': ginfo, 'hashvalue': 0},
                     priority=1)

    def remove_cached_graphinfo(self) -> None:
        """
        Remove the cached graph info.
        """
        self._cached_graphinfo = None

        # Also remove from session cache
        cache, key = self.getcache()
        if cache is not None:
            cache.remove(key, 'syncgraph-hash')

    def addepoch(self, ndi_daqsystem_obj: Any, ginfo: Dict[str, Any]) -> Dict[str, Any]:
        """
        Add an epoch from a DAQ system to the graph.

        Args:
            ndi_daqsystem_obj: DAQ system object
            ginfo: Current graph info

        Returns:
            Updated graph info

        Notes:
            This method will be fully implemented when DAQ system is complete.
            For now, it's a placeholder.
        """
        # TODO: Implement when DAQ system is available
        # This would:
        # 1. Get epoch nodes from the DAQ system
        # 2. Add nodes to the graph
        # 3. Add edges based on clock types
        # 4. Apply syncrules to find additional mappings
        return ginfo

    def time_convert(self, timeref_in: Any, t_in: float,
                    referent_out: Any, clocktype_out: ClockType) -> Tuple[Optional[float], Optional[Any], str]:
        """
        Convert time from one time reference to another.

        Args:
            timeref_in: Input time reference
            t_in: Input time value
            referent_out: Output referent (epochset)
            clocktype_out: Output clock type

        Returns:
            Tuple of (t_out, timeref_out, msg) where:
            - t_out: Converted time value (or None if conversion failed)
            - timeref_out: Output time reference (or None if conversion failed)
            - msg: Error message if conversion failed, empty string otherwise

        Notes:
            This method will be fully implemented when time reference and
            epoch systems are complete. For now, it's a placeholder.
        """
        t_out = None
        timeref_out = None
        msg = "time_convert not yet fully implemented - requires timereference and epoch systems"

        # TODO: Implement when timereference and epoch systems are available
        # This would:
        # 1. Find source node in graph
        # 2. Find destination node(s) in graph
        # 3. Find shortest path using graph algorithms
        # 4. Apply time mappings along the path

        return t_out, timeref_out, msg

    def getcache(self) -> Tuple[Optional[Any], Optional[str]]:
        """
        Get the cache and key for this syncgraph.

        Returns:
            Tuple of (cache, key) where:
            - cache: Session cache object (or None)
            - key: Cache key string (or None)
        """
        cache = None
        key = None

        if self.session is not None:
            if hasattr(self.session, 'cache'):
                cache = self.session.cache
                key = f'syncgraph_{self.id()}'

        return cache, key

    def newdocument(self) -> List[Document]:
        """
        Create NDI documents for this syncgraph.

        Returns:
            List of Document objects (syncgraph doc + all syncrule docs)
        """
        docs = []

        # Create syncgraph document
        syncgraph_doc = Document('syncgraph',
                                syncgraph_ndi_syncgraph_class=self.__class__.__module__ + '.' + self.__class__.__name__)
        syncgraph_doc.document_properties['base']['id'] = self.id()
        if self.session is not None:
            syncgraph_doc.document_properties['base']['session_id'] = self.session.id()
        else:
            syncgraph_doc.document_properties['base']['session_id'] = ''

        # Add dependencies to syncrules
        for rule in self.rules:
            syncgraph_doc = syncgraph_doc.add_dependency_value_n('syncrule_id', rule.id())
            docs.append(rule.newdocument())

        docs.insert(0, syncgraph_doc)
        return docs

    def searchquery(self) -> Query:
        """
        Create a search query for this syncgraph.

        Returns:
            Query object that searches for this syncgraph by ID and session ID
        """
        q = Query('base.id', 'exact_string', self.id())
        if self.session is not None:
            q = q & Query('base.session_id', 'exact_string', self.session.id())
        return q

    def __repr__(self) -> str:
        """String representation."""
        return f"SyncGraph(session={self.session}, rules={len(self.rules)})"

    def __str__(self) -> str:
        """String representation."""
        return self.__repr__()

    # Static methods

    @staticmethod
    def load_all_syncgraph_docs(ndi_session_obj: Any, syncgraph_doc_id: str) -> Tuple[Optional[Document], List[Document]]:
        """
        Load a syncgraph document and all of its syncrule documents.

        Args:
            ndi_session_obj: NDI session object
            syncgraph_doc_id: Document ID of the syncgraph

        Returns:
            Tuple of (syncgraph_doc, syncrule_docs) where:
            - syncgraph_doc: The syncgraph document (or None if not found)
            - syncrule_docs: List of syncrule documents

        Raises:
            ValueError: If multiple documents found with the same ID
        """
        syncrule_docs = []

        # Search for syncgraph document
        docs = ndi_session_obj.database_search(
            Query('base.id', 'exact_string', syncgraph_doc_id)
        )

        if len(docs) == 0:
            return None, []
        elif len(docs) > 1:
            raise ValueError(f"More than 1 document with base.id value of {syncgraph_doc_id}")

        syncgraph_doc = docs[0]

        # Load syncrule documents
        rules_id_list = syncgraph_doc.dependency_value_n('syncrule_id', error_if_not_found=False)
        for rule_id in rules_id_list:
            rules_doc = ndi_session_obj.database_search(
                Query('base.id', 'exact_string', rule_id)
            )
            if len(rules_doc) != 1:
                raise ValueError(f"Could not find syncrule with id {rule_id}; found {len(rules_doc)} occurrences")
            syncrule_docs.append(rules_doc[0])

        return syncgraph_doc, syncrule_docs
