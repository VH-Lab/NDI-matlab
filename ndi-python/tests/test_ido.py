"""
Tests for ndi.IDO - ID Object functionality
"""

import pytest
from ndi import IDO


class TestIDO:
    """Test suite for IDO class."""

    def test_ido_creation(self):
        """Test creating an IDO object."""
        ido = IDO()
        assert isinstance(ido, IDO)
        assert ido.identifier is not None
        assert len(ido.identifier) == 32

    def test_ido_with_provided_id(self):
        """Test creating IDO with provided identifier."""
        test_id = "a" * 32  # Valid 32-char hex string
        ido = IDO(test_id)
        assert ido.identifier == test_id

    def test_ido_invalid_id(self):
        """Test that invalid IDs raise errors."""
        # Too short
        with pytest.raises(ValueError):
            IDO("tooshort")

        # Too long
        with pytest.raises(ValueError):
            IDO("a" * 40)

        # Invalid characters
        with pytest.raises(ValueError):
            IDO("z" * 32)

    def test_id_method(self):
        """Test the id() method."""
        ido = IDO()
        assert ido.id() == ido.identifier

    def test_unique_id_static(self):
        """Test static unique_id method."""
        id1 = IDO.unique_id()
        id2 = IDO.unique_id()

        assert id1 != id2
        assert len(id1) == 32
        assert len(id2) == 32
        assert IDO.is_valid_id(id1)
        assert IDO.is_valid_id(id2)

    def test_is_valid_id(self):
        """Test ID validation."""
        # Valid IDs
        valid_id = "a" * 32
        assert IDO.is_valid_id(valid_id) is True

        valid_id2 = "0123456789abcdef" * 2
        assert IDO.is_valid_id(valid_id2) is True

        # Invalid IDs
        assert IDO.is_valid_id("tooshort") is False
        assert IDO.is_valid_id("a" * 40) is False
        assert IDO.is_valid_id("zzzzzzzz" * 4) is False
        assert IDO.is_valid_id(None) is False
        assert IDO.is_valid_id(123) is False

    def test_ido_equality(self):
        """Test IDO equality comparison."""
        ido1 = IDO()
        ido2 = IDO()

        # Different IDs should not be equal
        assert ido1 != ido2

        # Same object should be equal to itself
        assert ido1 == ido1

        # IDOs with same identifier should be equal
        test_id = "b" * 32
        ido3 = IDO(test_id)
        ido4 = IDO(test_id)
        assert ido3 == ido4

    def test_ido_hash(self):
        """Test IDO hashing for use in sets/dicts."""
        ido1 = IDO()
        ido2 = IDO()

        # Can be added to set
        ido_set = {ido1, ido2}
        assert len(ido_set) == 2

        # Can be used as dict key
        ido_dict = {ido1: 'value1', ido2: 'value2'}
        assert ido_dict[ido1] == 'value1'
        assert ido_dict[ido2] == 'value2'

    def test_ido_repr(self):
        """Test string representation."""
        ido = IDO()
        repr_str = repr(ido)

        assert 'IDO' in repr_str
        assert 'identifier' in repr_str
        assert ido.identifier[:8] in repr_str


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
