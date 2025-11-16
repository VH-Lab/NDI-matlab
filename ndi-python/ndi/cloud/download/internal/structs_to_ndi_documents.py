"""
Convert JSON structs to NDI documents.

Ported from MATLAB: ndi.cloud.download.internal.structsToNdiDocuments
"""

from typing import List, Dict, Any, Union
from ndi.document import Document


def structs_to_ndi_documents(document_structs: Union[List[Dict[str, Any]], Dict[str, Any]]) -> List[Document]:
    """
    Convert document structs (from JSON) to NDI Document objects.

    Args:
        document_structs: List of document dictionaries or single document dict

    Returns:
        List of Document objects

    Example:
        >>> structs = [{'document_class': {...}, 'document_properties': {...}}]
        >>> docs = structs_to_ndi_documents(structs)
    """
    # Handle single struct input
    if isinstance(document_structs, dict):
        document_structs = [document_structs]

    documents = []

    for struct in document_structs:
        try:
            # Create Document from properties
            if 'document_properties' in struct:
                doc = Document()
                doc.document_properties = struct['document_properties']
                documents.append(doc)
            else:
                # Legacy format: struct IS the document_properties
                doc = Document()
                doc.document_properties = struct
                documents.append(doc)

        except Exception as e:
            import warnings
            warnings.warn(f"Failed to convert struct to document: {e}")
            continue

    return documents
