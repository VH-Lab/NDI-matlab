"""
NDI Query - Query construction for searching documents.
"""

from typing import Any, List, Optional, Union
from enum import Enum


class QueryOp(Enum):
    """Query operation types."""

    EXACT_STRING = "exact_string"
    EXACT_NUMBER = "exact_number"
    CONTAINS_STRING = "contains_string"
    ISA = "isa"
    DEPENDS_ON = "depends_on"
    REGEXP = "regexp"
    GT = "greater_than"
    LT = "less_than"
    GTE = "greater_than_or_equal"
    LTE = "less_than_or_equal"


class Query:
    """
    NDI Query object for searching documents in a database.

    Supports field queries, logical operations (AND/OR), and various comparison operators.
    """

    def __init__(
        self,
        field: str = '',
        operation: str = '',
        value: Any = '',
        param: str = ''
    ):
        """
        Create a query object.

        Args:
            field: Field name to query (e.g., 'base.name')
            operation: Operation type (e.g., 'exact_string', 'isa', 'contains_string')
            value: Value to match
            param: Additional parameter (used for some operation types)

        Examples:
            >>> q = Query('base.name', 'exact_string', 'my_probe')
            >>> q = Query('', 'isa', 'element', '')
            >>> q1 = Query('base.name', 'exact_string', 'probe1')
            >>> q2 = Query('', 'isa', 'probe', '')
            >>> combined = q1 & q2  # AND operation
        """
        self.field = field
        self.operation = operation
        self.value = value
        self.param = param
        self.subqueries: List['Query'] = []
        self.logical_op: Optional[str] = None  # 'and' or 'or'

    def __and__(self, other: 'Query') -> 'Query':
        """
        Combine two queries with AND logic.

        Args:
            other: Another Query object

        Returns:
            Query: Combined query
        """
        result = Query()
        result.logical_op = 'and'
        result.subqueries = [self, other]
        return result

    def __or__(self, other: 'Query') -> 'Query':
        """
        Combine two queries with OR logic.

        Args:
            other: Another Query object

        Returns:
            Query: Combined query
        """
        result = Query()
        result.logical_op = 'or'
        result.subqueries = [self, other]
        return result

    def is_logical(self) -> bool:
        """
        Check if this is a logical combination query.

        Returns:
            bool: True if this is an AND/OR query
        """
        return self.logical_op is not None

    def matches(self, document: 'Document') -> bool:
        """
        Check if a document matches this query.

        Args:
            document: Document to check

        Returns:
            bool: True if document matches query
        """
        if self.is_logical():
            # Logical combination
            results = [q.matches(document) for q in self.subqueries]
            if self.logical_op == 'and':
                return all(results)
            else:  # 'or'
                return any(results)

        # Single field query
        return self._matches_single(document)

    def _matches_single(self, document: 'Document') -> bool:
        """
        Check if a document matches a single field query.

        Args:
            document: Document to check

        Returns:
            bool: True if matches
        """
        from .document import Document

        # Handle special 'isa' operation
        if self.operation == 'isa':
            return document.doc_isa(self.value)

        # Handle 'depends_on' operation
        if self.operation == 'depends_on':
            dep_value = document.dependency_value(self.value, error_if_not_found=False)
            if dep_value is None:
                return False
            # The param might specify what value we expect
            if self.param:
                return dep_value == self.param
            return True

        # Get field value from document
        field_value = self._get_field_value(document, self.field)
        if field_value is None:
            return False

        # Apply operation
        if self.operation == 'exact_string':
            return str(field_value) == str(self.value)
        elif self.operation == 'exact_number':
            try:
                return float(field_value) == float(self.value)
            except (ValueError, TypeError):
                return False
        elif self.operation == 'contains_string':
            return str(self.value) in str(field_value)
        elif self.operation == 'regexp':
            import re
            return bool(re.search(str(self.value), str(field_value)))
        elif self.operation == 'greater_than':
            try:
                return float(field_value) > float(self.value)
            except (ValueError, TypeError):
                return False
        elif self.operation == 'less_than':
            try:
                return float(field_value) < float(self.value)
            except (ValueError, TypeError):
                return False
        elif self.operation == 'greater_than_or_equal':
            try:
                return float(field_value) >= float(self.value)
            except (ValueError, TypeError):
                return False
        elif self.operation == 'less_than_or_equal':
            try:
                return float(field_value) <= float(self.value)
            except (ValueError, TypeError):
                return False

        return False

    @staticmethod
    def _get_field_value(document: 'Document', field: str) -> Any:
        """
        Get a field value from a document using dot notation.

        Args:
            document: Document to query
            field: Field path (e.g., 'base.name' or 'element.type')

        Returns:
            Field value or None if not found
        """
        if not field:
            return None

        parts = field.split('.')
        value = document.document_properties

        for part in parts:
            if isinstance(value, dict):
                if part not in value:
                    return None
                value = value[part]
            else:
                # Try attribute access
                if not hasattr(value, part):
                    return None
                value = getattr(value, part)

        return value

    def __repr__(self) -> str:
        """String representation of query."""
        if self.is_logical():
            subquery_strs = [repr(q) for q in self.subqueries]
            return f"({f' {self.logical_op.upper()} '.join(subquery_strs)})"
        else:
            return f"Query({self.field}={self.value})"
