"""
Cache management utilities for NDI.
"""

import os
import json
import pickle
import time
from typing import Any, Optional, Dict
from pathlib import Path


class SimpleCache:
    """Simple file-based cache for NDI."""

    def __init__(self, cache_dir: Optional[str] = None, ttl: int = 3600):
        """
        Initialize cache.

        Args:
            cache_dir: Cache directory (default: ~/.ndi/cache)
            ttl: Time-to-live in seconds (default: 1 hour)
        """
        if cache_dir is None:
            cache_dir = os.path.join(str(Path.home()), '.ndi', 'cache')

        self.cache_dir = cache_dir
        self.ttl = ttl
        os.makedirs(cache_dir, exist_ok=True)

    def _get_cache_path(self, key: str) -> str:
        """Get path to cache file for key."""
        safe_key = key.replace('/', '_').replace('\\', '_')
        return os.path.join(self.cache_dir, f'{safe_key}.cache')

    def get(self, key: str, default: Any = None) -> Any:
        """
        Get value from cache.

        Args:
            key: Cache key
            default: Default value if not found or expired

        Returns:
            Cached value or default
        """
        cache_path = self._get_cache_path(key)

        if not os.path.exists(cache_path):
            return default

        try:
            with open(cache_path, 'rb') as f:
                data = pickle.load(f)

            # Check if expired
            if time.time() - data['timestamp'] > self.ttl:
                os.remove(cache_path)
                return default

            return data['value']

        except Exception:
            return default

    def set(self, key: str, value: Any) -> None:
        """
        Set value in cache.

        Args:
            key: Cache key
            value: Value to cache
        """
        cache_path = self._get_cache_path(key)

        data = {
            'timestamp': time.time(),
            'value': value
        }

        try:
            with open(cache_path, 'wb') as f:
                pickle.dump(data, f)
        except Exception:
            pass  # Fail silently

    def clear(self) -> None:
        """Clear all cache entries."""
        for filename in os.listdir(self.cache_dir):
            if filename.endswith('.cache'):
                try:
                    os.remove(os.path.join(self.cache_dir, filename))
                except Exception:
                    pass
