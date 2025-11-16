"""
NDI Progress Tracker - Track and report progress of long-running operations.

This module provides the ProgressTracker class for managing progress state
and emitting progress events.
"""

from typing import Optional, Callable, Any
import time
import threading
from dataclasses import dataclass


@dataclass
class ProgressEvent:
    """Event data for progress updates."""
    fraction_complete: float
    message: Optional[str] = None
    elapsed_time: Optional[float] = None


class ProgressTracker:
    """
    Track progress of long-running operations and emit events.

    This class manages progress state and notifies listeners when progress
    is updated. It supports fractional progress (0.0 to 1.0) and optional
    status messages.

    Attributes:
        fraction_complete (float): Current progress (0.0 to 1.0)
        message (str): Current status message
        update_interval (float): Minimum seconds between progress notifications

    Example:
        >>> tracker = ProgressTracker()
        >>> tracker.on_progress_updated = lambda evt: print(f"Progress: {evt.fraction_complete:.1%}")
        >>> tracker.update_progress(0.5, "Halfway done")
        Progress: 50.0%
        >>> tracker.mark_complete()
        Progress: 100.0%
    """

    def __init__(self, update_interval: float = 0.1):
        """
        Initialize ProgressTracker.

        Args:
            update_interval: Minimum seconds between progress notifications (default: 0.1)
        """
        self.fraction_complete: float = 0.0
        self.message: Optional[str] = None
        self.update_interval: float = update_interval

        # Event callbacks
        self.on_progress_updated: Optional[Callable[[ProgressEvent], None]] = None
        self.on_message_updated: Optional[Callable[[str], None]] = None
        self.on_task_completed: Optional[Callable[[], None]] = None

        # Internal state
        self._start_time: Optional[float] = None
        self._last_update_time: float = 0.0
        self._lock = threading.Lock()

    def start(self) -> None:
        """Start tracking progress."""
        with self._lock:
            self._start_time = time.time()
            self._last_update_time = self._start_time
            self.fraction_complete = 0.0
            self.message = None

    def update_progress(self, fraction: float, message: Optional[str] = None) -> None:
        """
        Update progress and optionally the status message.

        Args:
            fraction: Progress fraction (0.0 to 1.0)
            message: Optional status message

        Example:
            >>> tracker = ProgressTracker()
            >>> tracker.update_progress(0.25, "Processing file 1 of 4")
        """
        with self._lock:
            if self._start_time is None:
                self.start()

            # Clamp fraction to valid range
            self.fraction_complete = max(0.0, min(1.0, fraction))

            if message is not None:
                self.message = message

            # Check if enough time has elapsed since last update
            current_time = time.time()
            if current_time - self._last_update_time >= self.update_interval:
                self._last_update_time = current_time
                self._emit_progress_event()

    def update_message(self, message: str) -> None:
        """
        Update the status message without changing progress.

        Args:
            message: New status message
        """
        with self._lock:
            self.message = message
            if self.on_message_updated:
                self.on_message_updated(message)

    def mark_complete(self) -> None:
        """Mark the task as complete (100% progress)."""
        with self._lock:
            self.fraction_complete = 1.0
            self._emit_progress_event()
            if self.on_task_completed:
                self.on_task_completed()

    def get_elapsed_time(self) -> Optional[float]:
        """
        Get elapsed time since tracking started.

        Returns:
            Elapsed time in seconds, or None if not started
        """
        with self._lock:
            if self._start_time is None:
                return None
            return time.time() - self._start_time

    def _emit_progress_event(self) -> None:
        """Emit a progress updated event (internal)."""
        if self.on_progress_updated:
            event = ProgressEvent(
                fraction_complete=self.fraction_complete,
                message=self.message,
                elapsed_time=self.get_elapsed_time()
            )
            self.on_progress_updated(event)

    def __repr__(self) -> str:
        """String representation of ProgressTracker."""
        return f"ProgressTracker(progress={self.fraction_complete:.1%}, message='{self.message}')"
