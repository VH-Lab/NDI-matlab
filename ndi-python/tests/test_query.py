"""
Tests for ndi.Query
"""

import pytest
from ndi import Query, Document


class TestQuery:
    """Test suite for Query class."""

    def test_query_creation(self):
        """Test creating query objects."""
        q = Query('base.name', 'exact_string', 'my_probe')
        assert q.field == 'base.name'
        assert q.operation == 'exact_string'
        assert q.value == 'my_probe'

    def test_query_and(self):
        """Test AND operation."""
        q1 = Query('base.name', 'exact_string', 'probe1')
        q2 = Query('', 'isa', 'probe', '')
        combined = q1 & q2
        assert combined.logical_op == 'and'
        assert len(combined.subqueries) == 2

    def test_query_or(self):
        """Test OR operation."""
        q1 = Query('base.name', 'exact_string', 'probe1')
        q2 = Query('base.name', 'exact_string', 'probe2')
        combined = q1 | q2
        assert combined.logical_op == 'or'
        assert len(combined.subqueries) == 2

    def test_exact_string_match(self):
        """Test exact string matching."""
        doc = Document('base')
        doc.document_properties['base']['name'] = 'test_probe'

        q = Query('base.name', 'exact_string', 'test_probe')
        assert q.matches(doc) is True

        q2 = Query('base.name', 'exact_string', 'other_probe')
        assert q2.matches(doc) is False

    def test_contains_string_match(self):
        """Test contains string matching."""
        doc = Document('base')
        doc.document_properties['base']['name'] = 'my_test_probe'

        q = Query('base.name', 'contains_string', 'test')
        assert q.matches(doc) is True

        q2 = Query('base.name', 'contains_string', 'other')
        assert q2.matches(doc) is False

    def test_exact_number_match(self):
        """Test exact number matching."""
        doc = Document('base')
        doc.document_properties['element'] = {'reference': 5}

        q = Query('element.reference', 'exact_number', 5)
        assert q.matches(doc) is True

        q2 = Query('element.reference', 'exact_number', 3)
        assert q2.matches(doc) is False

    def test_combined_query(self):
        """Test combined AND query."""
        doc = Document('base')
        doc.document_properties['base']['name'] = 'probe1'
        doc.document_properties['element'] = {'type': 'electrode'}

        q1 = Query('base.name', 'exact_string', 'probe1')
        q2 = Query('element.type', 'exact_string', 'electrode')
        combined = q1 & q2

        assert combined.matches(doc) is True

    def test_isa_operation(self):
        """Test ISA operation."""
        doc = Document('element')
        # Document class should be 'element'

        q = Query('', 'isa', 'element')
        assert q.matches(doc) is True

        q2 = Query('', 'isa', 'probe')
        assert q2.matches(doc) is False

    def test_all_query(self):
        """Test query that matches all documents."""
        # all_query should match documents of type 'base'
        # In MATLAB, this would match all documents since all inherit from base
        q = Query('', 'isa', 'base', '')

        # Should match 'base' documents
        doc_base = Document('base')
        assert q.matches(doc_base) is True

        # Note: In the Python implementation, we need explicit superclass handling
        # which would be added in full document schema implementation

    def test_none_query(self):
        """Test query that matches no documents."""
        # none_query uses a non-existent document type
        q = Query('', 'isa', 'nonexistentdocumenttype12345', '')

        doc_base = Document('base')
        assert q.matches(doc_base) is False

        doc_element = Document('element')
        assert q.matches(doc_element) is False

    def test_greater_than(self):
        """Test greater than comparison."""
        doc = Document('base')
        doc.document_properties['value'] = {'count': 10}

        q = Query('value.count', 'greater_than', 5)
        assert q.matches(doc) is True

        q2 = Query('value.count', 'greater_than', 15)
        assert q2.matches(doc) is False

    def test_less_than(self):
        """Test less than comparison."""
        doc = Document('base')
        doc.document_properties['value'] = {'count': 10}

        q = Query('value.count', 'less_than', 15)
        assert q.matches(doc) is True

        q2 = Query('value.count', 'less_than', 5)
        assert q2.matches(doc) is False

    def test_regexp_match(self):
        """Test regular expression matching."""
        doc = Document('base')
        doc.document_properties['base']['name'] = 'test_probe_001'

        q = Query('base.name', 'regexp', r'probe_\d+')
        assert q.matches(doc) is True

        q2 = Query('base.name', 'regexp', r'electrode_\d+')
        assert q2.matches(doc) is False


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
