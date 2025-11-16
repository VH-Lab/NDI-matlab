"""
NDI Cache - Memory cache with configurable replacement policies.
"""

import time
from typing import Any, Dict, List, Optional, Tuple
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class CacheEntry:
    """Represents a single cache entry."""

    key: str
    type: str
    data: Any
    priority: int = 0
    timestamp: float = field(default_factory=time.time)
    size_bytes: int = 0

    def __post_init__(self):
        """Calculate size after initialization."""
        if self.size_bytes == 0:
            self.size_bytes = self._estimate_size(self.data)

    @staticmethod
    def _estimate_size(obj: Any) -> int:
        """
        Estimate the size of an object in bytes.

        Args:
            obj: Object to estimate size of

        Returns:
            int: Estimated size in bytes
        """
        import sys

        # Handle numpy arrays
        try:
            import numpy as np
            if isinstance(obj, np.ndarray):
                return obj.nbytes
        except ImportError:
            pass

        # Use sys.getsizeof for other objects
        return sys.getsizeof(obj)


class Cache:
    """
    NDI Cache object for storing frequently accessed data in memory.

    Supports multiple replacement policies: FIFO, LIFO, and error.
    Priority-based eviction prevents high-priority items from being removed.
    """

    def __init__(self, maxMemory: int = 10e9, replacement_rule: str = 'fifo'):
        """
        Create a new cache object.

        Args:
            maxMemory: Maximum memory to use in bytes (default 10GB)
            replacement_rule: Replacement policy ('fifo', 'lifo', or 'error')
        """
        self.maxMemory = int(maxMemory)
        self.replacement_rule = replacement_rule.lower()
        self.table: List[CacheEntry] = []

        if self.replacement_rule not in ['fifo', 'lifo', 'error']:
            raise ValueError(f"Invalid replacement_rule: {replacement_rule}. "
                           "Must be 'fifo', 'lifo', or 'error'.")

    def bytes(self) -> int:
        """
        Get total bytes currently used in cache.

        Returns:
            int: Total bytes used
        """
        return sum(entry.size_bytes for entry in self.table)

    def add(self, key: str, type: str, data: Any, priority: int = 0) -> None:
        """
        Add data to the cache.

        Args:
            key: Cache key
            type: Data type identifier
            data: Data to cache
            priority: Priority level (higher = more important)
        """
        # Remove existing entry with same key/type
        self.remove(key, type, leavehandle=True)

        # Create new entry
        entry = CacheEntry(key=key, type=type, data=data, priority=priority)

        # Check if item is too large for cache
        if entry.size_bytes > self.maxMemory:
            raise ValueError(f"Item size ({entry.size_bytes}) exceeds maximum cache size ({self.maxMemory})")

        # Make space if needed
        self._make_space(entry.size_bytes, priority)

        # Add the entry
        self.table.append(entry)

    def lookup(self, key: str, type: str) -> Optional[CacheEntry]:
        """
        Look up data in the cache.

        Args:
            key: Cache key
            type: Data type identifier

        Returns:
            CacheEntry or None: The cache entry if found, None otherwise
        """
        for entry in self.table:
            if entry.key == key and entry.type == type:
                return entry
        return None

    def remove(self, key: str, type: str, leavehandle: bool = False) -> None:
        """
        Remove data from the cache.

        Args:
            key: Cache key
            type: Data type identifier
            leavehandle: If True, don't delete handle objects (e.g., figures)
        """
        for i, entry in enumerate(self.table):
            if entry.key == key and entry.type == type:
                # Delete handle if it's a handle type and leavehandle is False
                if not leavehandle and hasattr(entry.data, '__del__'):
                    try:
                        # For matplotlib figures or other handle types
                        if hasattr(entry.data, 'close'):
                            entry.data.close()
                    except:
                        pass

                self.table.pop(i)
                return

    def clear(self) -> None:
        """Clear all entries from the cache."""
        self.table.clear()

    def _make_space(self, needed_bytes: int, new_priority: int) -> None:
        """
        Make space in the cache for a new entry.

        Args:
            needed_bytes: Bytes needed for new entry
            new_priority: Priority of new entry

        Raises:
            RuntimeError: If replacement_rule is 'error' and cache is full
        """
        current_bytes = self.bytes()

        if current_bytes + needed_bytes <= self.maxMemory:
            return  # Enough space already

        if self.replacement_rule == 'error':
            raise RuntimeError("Cache is full and replacement_rule is 'error'")

        # Calculate bytes to free
        bytes_to_free = (current_bytes + needed_bytes) - self.maxMemory

        # Sort entries by priority (ascending) then by timestamp
        if self.replacement_rule == 'fifo':
            # Remove oldest low-priority items first
            sorted_entries = sorted(
                enumerate(self.table),
                key=lambda x: (x[1].priority, x[1].timestamp)
            )
        else:  # 'lifo'
            # Remove newest low-priority items first
            sorted_entries = sorted(
                enumerate(self.table),
                key=lambda x: (x[1].priority, -x[1].timestamp)
            )

        # Remove entries until we have enough space
        bytes_freed = 0
        indices_to_remove = []

        for idx, entry in sorted_entries:
            # Don't remove items with higher priority than the new item
            if entry.priority > new_priority:
                continue

            indices_to_remove.append(idx)
            bytes_freed += entry.size_bytes

            if bytes_freed >= bytes_to_free:
                break

        # Check if we can actually make enough space
        if bytes_freed < bytes_to_free:
            raise RuntimeError(
                f"Cannot make space for new item. Item priority ({new_priority}) "
                "is too low compared to existing items."
            )

        # Remove entries (in reverse order to maintain indices)
        for idx in sorted(indices_to_remove, reverse=True):
            self.table.pop(idx)
