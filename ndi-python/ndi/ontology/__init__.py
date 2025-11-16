"""
NDI Ontology System

Provides ontology lookup and management for NDI.

Main Usage:
    from ndi.ontology import Ontology
    id, name, prefix, definition, synonyms, short = Ontology.lookup('CL:0000000')
"""

from .ontology import Ontology
from .empty import EMPTY
from .ndic import NDIC
from .cl import CL
from .chebi import CHEBI
from .pato import PATO
from .om import OM
from .uberon import Uberon
from .ncbitaxon import NCBITaxon
from .ncit import NCIT
from .ncim import NCIm
from .pubchem import PubChem
from .rrid import RRID
from .wbstrain import WBStrain

__all__ = [
    'Ontology',
    'EMPTY',
    'NDIC',
    'CL',
    'CHEBI',
    'PATO',
    'OM',
    'Uberon',
    'NCBITaxon',
    'NCIT',
    'NCIm',
    'PubChem',
    'RRID',
    'WBStrain',
]
