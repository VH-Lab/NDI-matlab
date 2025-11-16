"""
NDI IDO (ID Object) - Base class for objects with unique identifiers.
"""

import uuid
from typing import Optional


class IDO:
    """
    Base class for NDI objects that have unique identifiers.

    This class provides unique ID generation and validation functionality.
    IDs are UUIDs in string format with dashes removed.
    """

    def __init__(self, identifier: Optional[str] = None):
        """
        Initialize an IDO object.

        Args:
            identifier: Optional pre-existing identifier. If None, generates a new one.
        """
        if identifier is None:
            self._identifier = self._generate_id()
        else:
            if not self.is_valid_id(identifier):
                raise ValueError(f"Invalid identifier format: {identifier}")
            self._identifier = identifier

    @property
    def identifier(self) -> str:
        """Get the object's unique identifier."""
        return self._identifier

    def id(self) -> str:
        """
        Return the unique identifier for this object.

        Returns:
            str: The unique identifier string
        """
        return self._identifier

    @staticmethod
    def _generate_id() -> str:
        """
        Generate a new unique identifier.

        Returns:
            str: A unique identifier string (UUID without dashes)
        """
        return str(uuid.uuid4()).replace('-', '')

    @staticmethod
    def unique_id() -> str:
        """
        Generate a new unique identifier (static method).

        Returns:
            str: A unique identifier string
        """
        return IDO._generate_id()

    @staticmethod
    def is_valid_id(identifier: str) -> bool:
        """
        Check if an identifier is valid.

        Args:
            identifier: The identifier string to validate

        Returns:
            bool: True if valid, False otherwise
        """
        if not isinstance(identifier, str):
            return False

        # Check length (UUID without dashes is 32 characters)
        if len(identifier) != 32:
            return False

        # Check if all characters are valid hex digits
        try:
            int(identifier, 16)
            return True
        except ValueError:
            return False

    def __eq__(self, other) -> bool:
        """
        Check equality based on identifier.

        Args:
            other: Another object to compare

        Returns:
            bool: True if identifiers match
        """
        if not isinstance(other, IDO):
            return False
        return self.identifier == other.identifier

    def __hash__(self) -> int:
        """
        Return hash based on identifier.

        Returns:
            int: Hash value
        """
        return hash(self.identifier)

    def __repr__(self) -> str:
        """
        String representation of the IDO.

        Returns:
            str: String representation
        """
        return f"{self.__class__.__name__}(identifier='{self.identifier[:8]}...')"
