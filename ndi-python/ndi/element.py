"""
NDI Element - Physical or logical measurement/stimulation elements.
"""

from typing import Optional, List
from .ido import IDO
from .documentservice import DocumentService


class Element(IDO, DocumentService):
    """
    NDI Element - represents a measurement or stimulation element.

    Elements can be physical (probes) or logical (derived data, inferred neurons, etc.).
    """

    def __init__(
        self,
        session,
        name: str,
        reference: int,
        element_type: str,
        underlying_element: Optional['Element'] = None,
        direct: bool = True,
        subject_id: Optional[str] = None,
        dependencies: Optional[dict] = None
    ):
        """
        Create an element.

        Args:
            session: Parent session
            name: Element name
            reference: Reference number
            element_type: Type of element
            underlying_element: Parent element (if any)
            direct: Whether this directly uses underlying data
            subject_id: Associated subject ID
            dependencies: Additional dependencies
        """
        IDO.__init__(self)

        self.session = session
        self.name = name
        self.reference = reference
        self.type = element_type
        self.underlying_element = underlying_element
        self.direct = direct
        self.subject_id = subject_id
        self.dependencies = dependencies or {}

    def elementstring(self) -> str:
        """
        Get a human-readable element string.

        Returns:
            str: Element string
        """
        return f"{self.name} | {self.reference}"

    def newdocument(self):
        """Create a document representing this element."""
        doc = self.session.newdocument('element',
            **{
                'element.ndi_element_class': self.__class__.__name__,
                'element.name': self.name,
                'element.reference': self.reference,
                'element.type': self.type,
                'element.direct': self.direct
            }
        )

        # Set dependencies
        underlying_id = ''
        if self.underlying_element:
            underlying_id = self.underlying_element.id()

        doc.set_dependency_value('underlying_element_id', underlying_id,
                                error_if_not_found=False)
        doc.set_dependency_value('subject_id', self.subject_id or '',
                                error_if_not_found=False)

        return doc

    def searchquery(self):
        """Get a search query for this element."""
        from .query import Query
        q = self.session.searchquery()
        q = q & Query('element.name', 'exact_string', self.name)
        q = q & Query('element.type', 'exact_string', self.type)
        q = q & Query('element.reference', 'exact_number', self.reference)
        return q

    def __repr__(self) -> str:
        """String representation."""
        return f"Element(name='{self.name}', type='{self.type}', ref={self.reference})"
