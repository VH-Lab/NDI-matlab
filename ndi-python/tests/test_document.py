"""
Tests for ndi.Document
"""

import pytest
from ndi import Document, IDO


class TestDocument:
    """Test suite for Document class."""

    def test_document_creation(self):
        """Test creating a document."""
        doc = Document('base')
        assert isinstance(doc, Document)
        assert 'base' in doc.document_properties
        assert 'id' in doc.document_properties['base']
        assert len(doc.id()) == 32  # UUID without dashes

    def test_document_with_properties(self):
        """Test creating document with properties."""
        doc = Document('base', **{'base.name': 'test_doc'})
        assert doc.document_properties['base']['name'] == 'test_doc'

    def test_set_session_id(self):
        """Test setting session ID."""
        doc = Document('base')
        ido = IDO()
        session_id = ido.id()
        doc.set_session_id(session_id)
        assert doc.session_id() == session_id

    def test_document_id(self):
        """Test document ID methods."""
        doc = Document('base')
        doc_id = doc.id()
        assert isinstance(doc_id, str)
        assert len(doc_id) == 32
        assert IDO.is_valid_id(doc_id)

    def test_doc_class(self):
        """Test document class methods."""
        doc = Document('base')
        assert doc.doc_class() == 'base'

    def test_dependency_value(self):
        """Test dependency methods."""
        doc = Document('element')

        # Add dependency
        doc.set_dependency_value('subject_id', 'subj123', error_if_not_found=False)

        # Retrieve dependency
        value = doc.dependency_value('subject_id')
        assert value == 'subj123'

    def test_dependency_not_found(self):
        """Test dependency error handling."""
        doc = Document('base')

        # Should raise error
        with pytest.raises(KeyError):
            doc.dependency_value('nonexistent')

        # Should return None
        value = doc.dependency_value('nonexistent', error_if_not_found=False)
        assert value is None

    def test_add_file(self):
        """Test adding file references."""
        doc = Document('base')
        doc.add_file('data.txt', '/path/to/data.txt')

        assert 'files' in doc.document_properties
        assert len(doc.document_properties['files']['file_info']) == 1
        assert doc.document_properties['files']['file_info'][0]['name'] == 'data.txt'

    def test_document_equality(self):
        """Test document equality."""
        doc1 = Document('base')
        doc2 = Document('base')

        # Different IDs
        assert doc1 != doc2

        # Same doc
        assert doc1 == doc1

    def test_document_merge(self):
        """Test document merging with + operator."""
        doc1 = Document('base')
        doc1.document_properties['field1'] = 'value1'

        doc2 = Document('base')
        doc2.document_properties['field2'] = 'value2'

        merged = doc1 + doc2
        assert 'field1' in merged.document_properties
        assert 'field2' in merged.document_properties


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
