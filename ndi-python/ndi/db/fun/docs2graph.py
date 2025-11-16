"""
NDI Database Function - Convert documents to dependency graph.

Create a directed graph from a list of ndi.document objects based on
'depends_on' relationships.
"""

from typing import List, Tuple, Any, Dict
import numpy as np


def docs2graph(ndi_document_objs: List[Any]) -> Tuple[np.ndarray, List[str], Any]:
    """
    Create a directed graph from a list of ndi.document objects.

    Given a list of ndi.document objects, this function creates a directed
    graph with the 'depends_on' relationships. If an object A 'depends on'
    another object B, there will be an edge from B to A (B→A).

    Args:
        ndi_document_objs: List of ndi.document objects

    Returns:
        Tuple of (adjacency_matrix, nodes, networkx_graph) where:
        - adjacency_matrix: Sparse numpy array (N x N) of dependencies
        - nodes: List of document IDs (node names)
        - networkx_graph: NetworkX DiGraph object (requires networkx installed)

    Examples:
        >>> from ndi.session import SessionDir
        >>> from ndi.database.fun import docs2graph
        >>> session = SessionDir('/path/to/session')
        >>> docs = session.database_search(ndi.Query('', 'all'))
        >>> adj_matrix, node_ids, graph = docs2graph(docs)
        >>> # adj_matrix[i, j] = 1 if doc i depends on doc j
        >>> # node_ids[i] is the document ID for row/column i

    Notes:
        - Edge direction: If A depends on B, edge goes from B to A (B→A)
        - Returns sparse matrix for memory efficiency
        - NetworkX graph requires networkx package (optional)
        - Only includes dependencies within the provided document set
        - Missing dependencies (not in document list) are ignored

    Raises:
        ImportError: If networkx is not installed (only for DiGraph return)
    """
    from scipy.sparse import lil_matrix

    # Extract node IDs
    nodes = [doc.document_properties.base.id for doc in ndi_document_objs]

    # Create sparse adjacency matrix
    n = len(nodes)
    G = lil_matrix((n, n), dtype=int)

    # Build adjacency matrix from dependencies
    for i, doc in enumerate(ndi_document_objs):
        here = i

        # Check if document has dependencies
        if hasattr(doc.document_properties, 'depends_on') and doc.document_properties.depends_on:
            deps = doc.document_properties.depends_on

            # Handle both single dependency and list of dependencies
            if not isinstance(deps, list):
                deps = [deps]

            for dep in deps:
                # Find the index of the dependency in our node list
                dep_value = dep.value if hasattr(dep, 'value') else dep.get('value')

                if dep_value in nodes:
                    there = nodes.index(dep_value)
                    # Edge from dependency (there) to dependent (here)
                    # If doc[here] depends on doc[there], edge is there→here
                    G[here, there] = 1

    # Convert to CSR format for efficiency
    G = G.tocsr()

    # Try to create NetworkX graph
    networkx_graph = None
    try:
        import networkx as nx
        # NetworkX expects edges as (from, to) pairs
        # Our G[i, j] = 1 means doc i depends on doc j, so edge is j→i
        edges = []
        rows, cols = G.nonzero()
        for row, col in zip(rows, cols):
            # row depends on col, so edge is col→row
            edges.append((nodes[col], nodes[row]))

        networkx_graph = nx.DiGraph()
        networkx_graph.add_nodes_from(nodes)
        networkx_graph.add_edges_from(edges)

    except ImportError:
        # NetworkX not installed, return None
        networkx_graph = None

    return G.toarray(), nodes, networkx_graph
