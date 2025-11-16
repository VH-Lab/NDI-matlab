"""
NDI Subject - Represents the subject of an experiment.
"""

from .ido import IDO


class Subject(IDO):
    """
    NDI Subject - represents an experimental subject.

    The subject is the object being sampled (animal, human, test resistor, etc.).
    """

    def __init__(
        self,
        session,
        local_identifier: str,
        **metadata
    ):
        """
        Create a subject.

        Args:
            session: Parent session
            local_identifier: Local identifier for the subject
            **metadata: Additional metadata (species, age, etc.)
        """
        super().__init__()

        self.session = session
        self.local_identifier = local_identifier
        self.metadata = metadata

    def newdocument(self):
        """Create a document representing this subject."""
        doc = self.session.newdocument('subject',
            **{
                'subject.local_identifier': self.local_identifier,
                **{f'subject.{k}': v for k, v in self.metadata.items()}
            }
        )
        return doc

    @staticmethod
    def does_subjectstring_match_session_document(
        session,
        subject_string: str,
        create_if_not_found: bool = False
    ) -> tuple:
        """
        Check if a subject string matches an existing subject document.

        Args:
            session: Session to search
            subject_string: Subject identifier
            create_if_not_found: If True, create new subject if not found

        Returns:
            Tuple of (found: bool, subject_id: str)
        """
        from .query import Query

        # Search for subject
        q = Query('subject.local_identifier', 'exact_string', subject_string)
        results = session.database_search(q)

        if results:
            return True, results[0].id()

        if create_if_not_found:
            # Create new subject
            subject = Subject(session, subject_string)
            doc = subject.newdocument()
            session.database_add(doc)
            return True, doc.id()

        return False, ''

    def __repr__(self) -> str:
        """String representation."""
        return f"Subject(identifier='{self.local_identifier}')"
