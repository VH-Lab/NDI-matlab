"""
Plot an interactive document dependency graph.

This module provides functionality to visualize NDI document dependencies
as an interactive graph using matplotlib and networkx.

Ported from MATLAB: src/ndi/+ndi/+database/+fun/plotinteractivedocgraph.m
"""

from typing import List, Optional
import warnings


def plotinteractivedocgraph(
    docs: List,
    G,
    mdigraph,
    nodes: List,
    layout: str = 'layered',
    interactive: bool = False
):
    """
    Plot an interactive document dependency graph.

    Given a list of NDI documents, a connectivity matrix G, a digraph object,
    and a list of node names, this plots a graph of the NDI documents.

    Args:
        docs: List of ndi.document objects
        G: Connectivity matrix (2D array or sparse matrix)
        mdigraph: NetworkX DiGraph object
        nodes: List of node names (document IDs)
        layout: Graph layout algorithm ('spring', 'circular', 'kamada_kawai', 'planar', 'shell')
        interactive: If True, enable click interactions to display document info

    Example:
        >>> from ndi.session import Session
        >>> from ndi.db.fun import docs2graph, plotinteractivedocgraph
        >>> session = Session('/path/to/session')
        >>> docs = session.database_search(Query('base.id', 'regexp', '.*', ''))
        >>> G, nodes, mdigraph = docs2graph(docs)
        >>> plotinteractivedocgraph(docs, G, mdigraph, nodes, layout='spring')

    Notes:
        - Requires matplotlib and networkx libraries
        - Interactive mode allows clicking near nodes to display document properties
        - Layout options depend on networkx available layouts:
          - 'spring': Force-directed layout
          - 'circular': Nodes arranged in a circle
          - 'kamada_kawai': Energy-minimization layout
          - 'planar': Planar layout (if graph is planar)
          - 'shell': Concentric circles layout
        - In interactive mode, clicking near a node prints its properties
        - Non-interactive mode shows document info as tooltips (if supported)
    """
    try:
        import matplotlib.pyplot as plt
        import networkx as nx
        import numpy as np
    except ImportError as e:
        warnings.warn(
            f"plotinteractivedocgraph requires matplotlib and networkx: {e}\n"
            "Install with: pip install matplotlib networkx"
        )
        return

    # Validate inputs
    if not docs:
        warnings.warn("No documents to plot")
        return

    if len(docs) != len(nodes):
        warnings.warn(f"Number of docs ({len(docs)}) != number of nodes ({len(nodes)})")

    # Create figure
    fig, ax = plt.subplots(figsize=(12, 8))

    # Select layout algorithm
    layout_funcs = {
        'spring': nx.spring_layout,
        'circular': nx.circular_layout,
        'kamada_kawai': nx.kamada_kawai_layout,
        'shell': nx.shell_layout,
        'planar': nx.planar_layout,
    }

    # Map 'layered' to 'kamada_kawai' (closest equivalent to MATLAB's layered)
    if layout == 'layered':
        layout = 'kamada_kawai'

    if layout not in layout_funcs:
        warnings.warn(f"Unknown layout '{layout}', using 'spring'")
        layout = 'spring'

    # Compute node positions
    try:
        pos = layout_funcs[layout](mdigraph)
    except Exception as e:
        warnings.warn(f"Layout '{layout}' failed: {e}, using 'spring'")
        pos = nx.spring_layout(mdigraph)

    # Draw the graph
    nx.draw(
        mdigraph,
        pos,
        ax=ax,
        with_labels=False,
        node_color='lightblue',
        node_size=500,
        edge_color='gray',
        arrows=True,
        arrowsize=10,
        font_size=8
    )

    # Add node labels (truncated document IDs)
    labels = {node: node[:8] + '...' if len(node) > 8 else node for node in nodes}
    nx.draw_networkx_labels(mdigraph, pos, labels, ax=ax, font_size=6)

    ax.set_title('NDI Document Dependency Graph')
    ax.axis('off')

    # Store data in figure for interactive mode
    if interactive:
        # Create a mapping from node names to documents
        node_to_doc = {nodes[i]: docs[i] for i in range(min(len(nodes), len(docs)))}
        fig.node_to_doc = node_to_doc
        fig.pos = pos
        fig.nodes = nodes

        # Connect click event
        def onclick(event):
            if event.inaxes != ax:
                return

            # Find closest node to click
            click_pos = np.array([event.xdata, event.ydata])
            min_dist = float('inf')
            closest_node = None

            for node, (x, y) in pos.items():
                dist = np.sqrt((x - click_pos[0])**2 + (y - click_pos[1])**2)
                if dist < min_dist:
                    min_dist = dist
                    closest_node = node

            if closest_node and closest_node in node_to_doc:
                doc = node_to_doc[closest_node]
                print(f"\n=== Clicked Node: {closest_node} ===")
                print(f"Document Properties:")
                for key, value in doc.document_properties.items():
                    print(f"  {key}: {value}")
                print(f"Document Class: {doc.document_properties.get('document_class', {})}")
                print(f"Base Properties: {doc.document_properties.get('base', {})}")
                print("="*50)

        fig.canvas.mpl_connect('button_press_event', onclick)
        print("Interactive mode: Click near a node to display its properties")

    plt.tight_layout()
    plt.show()


def plotinteractivedocgraph_from_session(
    session,
    query_str: Optional[str] = None,
    layout: str = 'spring',
    interactive: bool = True
):
    """
    Convenience function to plot document graph directly from a session.

    Args:
        session: ndi.session object
        query_str: Optional query string (regex pattern for document IDs)
        layout: Graph layout algorithm
        interactive: Enable interactive mode

    Example:
        >>> from ndi.session import Session
        >>> session = Session('/path/to/session')
        >>> plotinteractivedocgraph_from_session(session, interactive=True)
    """
    from ndi.query import Query
    from .docs2graph import docs2graph

    # Search for all documents
    if query_str:
        q = Query('base.id', 'regexp', query_str, '')
    else:
        q = Query('base.id', 'regexp', '.*', '')

    docs = session.database_search(q)

    if not docs:
        print("No documents found")
        return

    # Ensure docs is a list
    if not isinstance(docs, list):
        docs = [docs]

    # Build graph
    G, nodes, mdigraph = docs2graph(docs)

    # Plot
    plotinteractivedocgraph(docs, G, mdigraph, nodes, layout, interactive)
