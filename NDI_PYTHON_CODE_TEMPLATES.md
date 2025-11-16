# NDI-Python Code Templates

**Quick Reference for Porting MATLAB to Python**

---

## Template 1: Basic Method Port

```python
def method_name(self, param1: str, param2: int = 0) -> ReturnType:
    """
    Brief description matching MATLAB help text.

    Longer description explaining what the method does.
    MATLAB equivalent: ndi.ClassName.methodName()

    Args:
        param1: Parameter description
        param2: Parameter description (default: 0)

    Returns:
        Description of return value

    Raises:
        ValueError: When param1 is invalid
        TypeError: When param2 is wrong type

    Example:
        >>> obj = ClassName()
        >>> result = obj.method_name('test', 5)
        >>> print(result)

    See Also:
        related_method, other_class.method
    """
    # Input validation
    if not param1:
        raise ValueError("param1 cannot be empty")

    # Implementation
    result = self._do_something(param1, param2)

    return result
```

---

## Template 2: Property with Validation

```python
class ClassName:
    def __init__(self):
        self._property_name = None  # Private backing field

    @property
    def property_name(self) -> str:
        """
        Property description.

        MATLAB equivalent: obj.propertyName (GetAccess=public)

        Returns:
            Current property value
        """
        return self._property_name

    @property_name.setter
    def property_name(self, value: str) -> None:
        """
        Set property with validation.

        MATLAB equivalent: obj.propertyName = value (SetAccess=protected)

        Args:
            value: New property value

        Raises:
            ValueError: If value is invalid
        """
        if not isinstance(value, str):
            raise TypeError("property_name must be string")
        if not value:
            raise ValueError("property_name cannot be empty")

        self._property_name = value
```

---

## Template 3: Static Method

```python
@staticmethod
def static_method(arg1: str, arg2: int) -> List[str]:
    """
    Static method description.

    MATLAB equivalent: ndi.ClassName.staticMethod(arg1, arg2)

    Args:
        arg1: Description
        arg2: Description

    Returns:
        List of results

    Example:
        >>> results = ClassName.static_method('test', 5)
    """
    results = []
    # Implementation
    return results
```

---

## Template 4: Class Method (Alternative Constructor)

```python
@classmethod
def from_dict(cls, data: Dict[str, Any]) -> 'ClassName':
    """
    Create instance from dictionary.

    Alternative constructor pattern.

    Args:
        data: Dictionary with initialization data

    Returns:
        New instance of ClassName

    Example:
        >>> data = {'name': 'test', 'value': 5}
        >>> obj = ClassName.from_dict(data)
    """
    obj = cls(data['name'])
    obj.value = data.get('value', 0)
    return obj
```

---

## Template 5: Iterator Protocol

```python
def __iter__(self):
    """Iterate over items."""
    return iter(self._items)

def __len__(self):
    """Return number of items."""
    return len(self._items)

def __getitem__(self, index: int):
    """Get item by index."""
    return self._items[index]
```

---

## Template 6: Context Manager (for Resources)

```python
def __enter__(self):
    """Enter context - open resource."""
    self._resource = self._open_resource()
    return self

def __exit__(self, exc_type, exc_val, exc_tb):
    """Exit context - close resource."""
    if self._resource:
        self._close_resource()
    return False  # Don't suppress exceptions
```

---

## Template 7: Database Operation

```python
def database_operation(self, query: Query) -> List[Document]:
    """
    Perform database operation with error handling.

    Args:
        query: Search query

    Returns:
        List of matching documents

    Raises:
        DatabaseError: If operation fails
    """
    if not self.database:
        raise RuntimeError("Database not initialized")

    try:
        results = self.database.search(query)

        # Log operation
        from .fun import console
        console(f"Found {len(results)} documents", priority=0)

        return results

    except Exception as e:
        from .fun import errlog
        errlog(f"Database operation failed: {e}")
        raise DatabaseError(f"Search failed: {e}") from e
```

---

## Template 8: File I/O with Path Handling

```python
from pathlib import Path
from typing import Union

def read_file(self, file_path: Union[str, Path]) -> str:
    """
    Read file with proper path handling.

    Args:
        file_path: Path to file (string or Path object)

    Returns:
        File contents

    Raises:
        FileNotFoundError: If file doesn't exist
        IOError: If read fails
    """
    path = Path(file_path)

    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    if not path.is_file():
        raise ValueError(f"Not a file: {path}")

    try:
        with open(path, 'r') as f:
            content = f.read()
        return content

    except IOError as e:
        raise IOError(f"Failed to read {path}: {e}") from e
```

---

## Template 9: Numpy Array Operation

```python
import numpy as np
from typing import Union

def process_array(self, data: Union[np.ndarray, List]) -> np.ndarray:
    """
    Process array data.

    Args:
        data: Input data (numpy array or list)

    Returns:
        Processed numpy array

    Raises:
        ValueError: If data is invalid
    """
    # Convert to numpy array if needed
    arr = np.asarray(data)

    # Validate shape/type
    if arr.ndim != 2:
        raise ValueError(f"Expected 2D array, got {arr.ndim}D")

    if not np.issubdtype(arr.dtype, np.number):
        raise TypeError(f"Expected numeric array, got {arr.dtype}")

    # Process
    result = np.zeros_like(arr)
    # ... processing logic ...

    return result
```

---

## Template 10: Type Checking Function

```python
from typing import Any, Type, Union

def check_type(value: Any, expected_type: Union[Type, tuple],
               param_name: str = 'value') -> None:
    """
    Check type with helpful error message.

    Args:
        value: Value to check
        expected_type: Expected type or tuple of types
        param_name: Parameter name for error message

    Raises:
        TypeError: If value is wrong type
    """
    if not isinstance(value, expected_type):
        if isinstance(expected_type, tuple):
            type_names = ' or '.join(t.__name__ for t in expected_type)
        else:
            type_names = expected_type.__name__

        actual_type = type(value).__name__
        raise TypeError(
            f"{param_name} must be {type_names}, got {actual_type}"
        )
```

---

## Template 11: Query Building Pattern

```python
from .query import Query

def build_search_query(self, **criteria) -> Query:
    """
    Build search query from criteria.

    Args:
        **criteria: Search criteria (name=value pairs)

    Returns:
        Constructed Query object

    Example:
        >>> q = obj.build_search_query(name='test', type='probe')
    """
    queries = []

    if 'name' in criteria:
        q = Query('base.name', 'exact_string', criteria['name'], '')
        queries.append(q)

    if 'type' in criteria:
        q = Query('', 'isa', criteria['type'], '')
        queries.append(q)

    # Combine with AND
    if not queries:
        return Query('', 'all', '', '')  # Match all

    result = queries[0]
    for q in queries[1:]:
        result = result & q

    return result
```

---

## Template 12: Caching Pattern

```python
from functools import lru_cache
from typing import Optional

class CachedClass:
    def __init__(self):
        self._cache = {}

    def get_with_cache(self, key: str) -> Optional[Any]:
        """Get value with caching."""
        # Check cache first
        if key in self._cache:
            return self._cache[key]

        # Compute if not cached
        value = self._compute_value(key)

        # Store in cache
        if value is not None:
            self._cache[key] = value

        return value

    def clear_cache(self) -> None:
        """Clear all cached values."""
        self._cache.clear()
```

---

## Template 13: Enum for Constants

```python
from enum import Enum, auto

class ReplacementRule(Enum):
    """Cache replacement rules."""
    FIFO = 'fifo'
    LIFO = 'lifo'
    ERROR = 'error'

# Usage:
def set_rule(self, rule: ReplacementRule) -> None:
    """Set replacement rule."""
    self.replacement_rule = rule

# Called as:
obj.set_rule(ReplacementRule.FIFO)
```

---

## Template 14: Dataclass for Simple Structures

```python
from dataclasses import dataclass, field
from typing import List, Optional

@dataclass
class CacheEntry:
    """Cache entry structure."""
    key: str
    data_type: str
    data: Any
    priority: int = 0
    size_bytes: int = 0
    timestamp: float = field(default_factory=time.time)

# Usage:
entry = CacheEntry(
    key='mydata',
    data_type='timeseries',
    data=array,
    priority=5
)
```

---

## Template 15: Exception Handling Patterns

```python
# Pattern 1: Catch and re-raise with context
try:
    result = self._risky_operation()
except SpecificError as e:
    raise RuntimeError(f"Operation failed: {e}") from e

# Pattern 2: Multiple exception types
try:
    result = self._operation()
except (ValueError, TypeError) as e:
    self._handle_error(e)
    raise
except Exception as e:
    self._log_unexpected_error(e)
    raise

# Pattern 3: Finally for cleanup
resource = None
try:
    resource = self._acquire_resource()
    result = self._use_resource(resource)
finally:
    if resource:
        self._release_resource(resource)
```

---

## Template 16: Logging Integration

```python
def method_with_logging(self, param: str) -> bool:
    """Method with integrated logging."""
    from .fun import console, debuglog, errlog

    # Debug logging
    debuglog(f"method_with_logging called with param={param}")

    try:
        # Info logging
        console(f"Processing {param}", priority=0)

        result = self._process(param)

        # Success logging
        console(f"Successfully processed {param}", priority=0)

        return result

    except Exception as e:
        # Error logging
        errlog(f"Failed to process {param}: {e}")
        raise
```

---

## Template 17: Abstract Base Class

```python
from abc import ABC, abstractmethod

class AbstractBase(ABC):
    """Abstract base class."""

    @abstractmethod
    def required_method(self) -> str:
        """
        Subclasses must implement this.

        Returns:
            Implementation-specific result
        """
        pass

    def optional_method(self) -> int:
        """
        Subclasses can override this.

        Returns:
            Default value
        """
        return 0

class ConcreteImplementation(AbstractBase):
    """Concrete implementation."""

    def required_method(self) -> str:
        """Implementation of required method."""
        return "implemented"
```

---

## Template 18: Unit Test Structure

```python
import pytest
from ndi.module import ClassName

class TestClassName:
    """Tests for ClassName."""

    @pytest.fixture
    def instance(self):
        """Create test instance."""
        return ClassName('test')

    def test_method_success(self, instance):
        """Test method with valid input."""
        result = instance.method('valid')
        assert result is not None
        assert isinstance(result, str)

    def test_method_error(self, instance):
        """Test method with invalid input."""
        with pytest.raises(ValueError, match="cannot be empty"):
            instance.method('')

    def test_method_edge_case(self, instance):
        """Test method edge case."""
        # Test boundary condition
        result = instance.method('x' * 1000)
        assert len(result) > 0
```

---

## Template 19: MATLAB Cell Array to Python

```python
# MATLAB: cell_array = {'item1', 'item2', 'item3'}
# Python: list
items = ['item1', 'item2', 'item3']

# MATLAB: cell_array{1} (1-indexed)
# Python: items[0] (0-indexed)
first_item = items[0]

# MATLAB: numel(cell_array)
# Python: len(items)
count = len(items)

# MATLAB: cellfun(@func, cell_array)
# Python: list comprehension or map
results = [func(item) for item in items]
# or
results = list(map(func, items))
```

---

## Template 20: MATLAB Struct to Python

```python
from typing import Dict, Any

# MATLAB: s.field1 = value1; s.field2 = value2;
# Python: Dictionary
s = {
    'field1': value1,
    'field2': value2
}

# Or use dataclass for type safety
from dataclasses import dataclass

@dataclass
class StructEquivalent:
    field1: str
    field2: int

s = StructEquivalent(field1='value', field2=42)
```

---

## Quick Reference: MATLAB → Python Mappings

| MATLAB | Python | Notes |
|--------|--------|-------|
| `isempty(x)` | `not x` or `len(x) == 0` | For strings/lists |
| `numel(x)` | `len(x)` | For lists |
| `size(x)` | `x.shape` | For numpy arrays |
| `strcmp(s1, s2)` | `s1 == s2` | String comparison |
| `strcmpi(s1, s2)` | `s1.lower() == s2.lower()` | Case-insensitive |
| `contains(s, pat)` | `pat in s` | Substring check |
| `isa(obj, 'class')` | `isinstance(obj, Class)` | Type check |
| `class(obj)` | `type(obj).__name__` | Class name |
| `nargin` | `len(locals())` or defaults | Argument count |
| `varargin` | `*args` | Variable args |
| `try/catch` | `try/except` | Exception handling |
| `error('msg')` | `raise ValueError('msg')` | Error throwing |
| `warning('msg')` | `import warnings; warnings.warn('msg')` | Warnings |

---

## Best Practices

### 1. Type Hints

Always use type hints:
```python
def method(self, param: str, count: int = 0) -> List[str]:
    pass
```

### 2. Docstrings

Follow NumPy/Google style:
```python
def method(param):
    """
    Brief description.

    Longer description with details.

    Args:
        param: Parameter description

    Returns:
        Return value description

    Raises:
        ValueError: When condition occurs
    """
```

### 3. Error Messages

Be specific and helpful:
```python
# Good
raise ValueError(f"Expected positive integer, got {value}")

# Bad
raise ValueError("Invalid input")
```

### 4. Code Organization

```python
# 1. Imports
from typing import List
import numpy as np

# 2. Constants
DEFAULT_SIZE = 100

# 3. Helper functions
def _private_helper():
    pass

# 4. Class definition
class ClassName:
    # 5. Class variables
    class_var = 'value'

    # 6. __init__
    def __init__(self):
        pass

    # 7. Public methods
    def public_method(self):
        pass

    # 8. Private methods
    def _private_method(self):
        pass

    # 9. Properties
    @property
    def property_name(self):
        pass

    # 10. Static/class methods
    @staticmethod
    def static_method():
        pass
```

### 5. Testing

Write tests first (TDD):
```python
# 1. Write test
def test_feature():
    obj = Class()
    assert obj.feature() == expected

# 2. Implement
def feature(self):
    return expected

# 3. Refactor
```

---

**END OF CODE TEMPLATES**
