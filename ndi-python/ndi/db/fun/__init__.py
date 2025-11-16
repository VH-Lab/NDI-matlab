"""
NDI Database Functions - Utility functions for database operations.

This module provides utility functions for working with NDI databases,
including document retrieval, dependency traversal, graph generation,
dataset management, OpenMINDS integration, and ontology lookups.
"""

# Core database utilities
from .docs_from_ids import docs_from_ids
from .findalldependencies import findalldependencies
from .findallantecedents import findallantecedents
from .docs2graph import docs2graph
from .extract_docs_files import extract_docs_files
from .ndicloud_metadata import ndicloud_metadata

# Dataset management utilities
from .copy_session_to_dataset import copy_session_to_dataset
from .database2json import database2json

# Document search and analysis utilities
from .finddocs_missing_dependencies import finddocs_missing_dependencies
from .finddocs_elementEpochType import finddocs_elementEpochType
from .find_ingested_docs import find_ingested_docs

# Document file utilities
from .copydocfile2temp import copydocfile2temp
from .ndi_document2ndi_object import ndi_document2ndi_object

# OpenMINDS integration utilities
from .openMINDSobj2ndi_document import openMINDSobj2ndi_document
from .openMINDSobj2struct import openMINDSobj2struct

# Ontology lookup utilities
from .uberon_ontology_lookup import uberon_ontology_lookup, lookup_uberon_term
from .ndicloud_ontology_lookup import ndicloud_ontology_lookup

# Database management utilities
from .opendatabase import opendatabase
from .create_new_database import create_new_database, create_new_database_simple
from .databasehierarchyinit import (
    databasehierarchyinit,
    get_database_by_name,
    get_database_by_priority,
    get_default_database
)

# Visualization utilities
from .plotinteractivedocgraph import (
    plotinteractivedocgraph,
    plotinteractivedocgraph_from_session
)

__all__ = [
    # Core utilities
    'docs_from_ids',
    'findalldependencies',
    'findallantecedents',
    'docs2graph',
    'extract_docs_files',
    'ndicloud_metadata',
    # Dataset management
    'copy_session_to_dataset',
    'database2json',
    # Document search
    'finddocs_missing_dependencies',
    'finddocs_elementEpochType',
    'find_ingested_docs',
    # Document files
    'copydocfile2temp',
    'ndi_document2ndi_object',
    # OpenMINDS
    'openMINDSobj2ndi_document',
    'openMINDSobj2struct',
    # Ontology
    'uberon_ontology_lookup',
    'lookup_uberon_term',
    'ndicloud_ontology_lookup',
    # Database management
    'opendatabase',
    'create_new_database',
    'create_new_database_simple',
    'databasehierarchyinit',
    'get_database_by_name',
    'get_database_by_priority',
    'get_default_database',
    # Visualization
    'plotinteractivedocgraph',
    'plotinteractivedocgraph_from_session',
]
