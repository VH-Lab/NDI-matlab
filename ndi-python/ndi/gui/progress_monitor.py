"""
NDI Progress Monitor - Display progress of long-running operations.

This module provides progress monitor classes for displaying progress
to users via console output or optional GUI.
"""

from abc import ABC, abstractmethod
from typing import Optional
import sys
import time
from datetime import datetime, timedelta
from .progress_tracker import ProgressTracker, ProgressEvent


class ProgressMonitor(ABC):
    """
    Abstract base class for progress monitors.

    Subclasses must implement updateProgressDisplay(), updateMessage(),
    and finish() methods.

    Attributes:
        title (str): Title/description of the operation
        tracker (ProgressTracker): Progress tracker instance
        display_elapsed_time (bool): Whether to display elapsed time
        display_remaining_time (bool): Whether to display estimated remaining time
    """

    def __init__(self,
                 title: str = "In progress...",
                 tracker: Optional[ProgressTracker] = None,
                 display_elapsed_time: bool = False,
                 display_remaining_time: bool = True):
        """
        Initialize ProgressMonitor.

        Args:
            title: Title/description of the operation
            tracker: ProgressTracker instance (creates new one if None)
            display_elapsed_time: Whether to show elapsed time
            display_remaining_time: Whether to show estimated remaining time
        """
        self.title = title
        self.display_elapsed_time = display_elapsed_time
        self.display_remaining_time = display_remaining_time

        # Time tracking
        self._start_time: Optional[float] = None
        self._is_initialized = False

        # Set tracker and attach event handlers
        if tracker is None:
            tracker = ProgressTracker()

        self.tracker = tracker
        self.tracker.on_progress_updated = self._on_progress_updated
        self.tracker.on_message_updated = self._on_message_updated
        self.tracker.on_task_completed = self._on_task_completed

    def reset(self) -> None:
        """Reset the progress monitor to initial state."""
        self._start_time = None
        self._is_initialized = False

    def mark_complete(self) -> None:
        """Mark the task as complete."""
        self.tracker.mark_complete()

    @abstractmethod
    def update_progress_display(self) -> None:
        """Update the progress display (must be implemented by subclass)."""
        pass

    @abstractmethod
    def update_message(self, message: str) -> None:
        """Update the status message (must be implemented by subclass)."""
        pass

    @abstractmethod
    def finish(self) -> None:
        """Finish the progress display (must be implemented by subclass)."""
        pass

    def get_progress_message(self) -> str:
        """
        Get formatted progress message including time estimates.

        Returns:
            Formatted progress message string
        """
        msg = self.tracker.message or ''

        if self.display_remaining_time and self._is_initialized:
            remaining_time = self._estimate_remaining_time()
            if remaining_time is not None:
                remaining_str = self._format_time_duration(remaining_time)
                msg = f"{msg} Estimated time remaining: {remaining_str}".strip()

        return msg

    def get_progress_value(self) -> float:
        """
        Get current progress value (0.0 to 1.0).

        Returns:
            Progress fraction
        """
        return self.tracker.fraction_complete

    def _on_progress_updated(self, event: ProgressEvent) -> None:
        """Handle progress updated event (internal)."""
        if not self._is_initialized:
            self._initialize()
        self.update_progress_display()

    def _on_message_updated(self, message: str) -> None:
        """Handle message updated event (internal)."""
        self.update_message(message)

    def _on_task_completed(self) -> None:
        """Handle task completed event (internal)."""
        self.finish()

    def _initialize(self) -> None:
        """Initialize time tracking (internal)."""
        self._start_time = time.time()
        self._is_initialized = True

    def _estimate_remaining_time(self) -> Optional[float]:
        """
        Estimate remaining time based on current progress.

        Returns:
            Estimated remaining seconds, or None if cannot estimate
        """
        if self._start_time is None:
            return None

        fraction = self.tracker.fraction_complete
        if fraction <= 0.0:
            return None

        elapsed = time.time() - self._start_time
        total_estimated = elapsed / fraction
        remaining = total_estimated * (1.0 - fraction)

        return remaining

    @staticmethod
    def _format_time_duration(seconds: float) -> str:
        """
        Format time duration as human-readable string.

        Args:
            seconds: Duration in seconds

        Returns:
            Formatted string (e.g., "2 minutes, 30 seconds")
        """
        if seconds < 0:
            return "N/A"

        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)

        if hours > 0:
            return f"{hours} hours, {minutes} minutes"
        elif minutes > 0:
            return f"{minutes} minutes, {secs} seconds"
        else:
            return f"{secs} seconds"


class ConsoleProgressMonitor(ProgressMonitor):
    """
    Console-based progress monitor that prints to stdout.

    This monitor displays progress updates as text in the console,
    with optional timestamps and in-place updates.

    Example:
        >>> tracker = ProgressTracker()
        >>> monitor = ConsoleProgressMonitor("Processing files", tracker=tracker)
        >>> tracker.start()
        >>> tracker.update_progress(0.5, "File 5 of 10")
        [2025-01-16 10:30:45]: Processing files
        [2025-01-16 10:30:46]: File 5 of 10. Estimated time remaining: 5 seconds
        >>> tracker.mark_complete()
    """

    def __init__(self,
                 title: str = "In progress...",
                 tracker: Optional[ProgressTracker] = None,
                 show_timestamp: bool = True,
                 timestamp_format: str = "[%Y-%m-%d %H:%M:%S]",
                 update_inplace: bool = False,
                 indent_size: int = 0):
        """
        Initialize ConsoleProgressMonitor.

        Args:
            title: Title/description of the operation
            tracker: ProgressTracker instance
            show_timestamp: Whether to show timestamps
            timestamp_format: strftime format for timestamps
            update_inplace: Whether to update in-place (overwrite previous line)
            indent_size: Number of spaces to indent messages
        """
        super().__init__(title, tracker, display_remaining_time=True)

        self.show_timestamp = show_timestamp
        self.timestamp_format = timestamp_format
        self.update_inplace = update_inplace
        self.indent_size = indent_size

        self._previous_message: Optional[str] = None
        self._title_printed = False

    def reset(self) -> None:
        """Reset the monitor."""
        super().reset()
        self._previous_message = None
        self._title_printed = False

    def update_progress_display(self) -> None:
        """Update the progress display in console."""
        if not self._title_printed:
            self._print_title_message()
            self._title_printed = True

        msg = self.tracker.message
        if msg:
            self._update_progress_message(msg)

    def update_message(self, message: str) -> None:
        """Update the status message."""
        message = self._format_message(message)
        self._previous_message = ''
        self._print_message(message)

    def finish(self) -> None:
        """Finish the progress display."""
        self.update_progress_display()
        # Optionally print completion message
        # print()  # Extra newline

    def _print_title_message(self) -> None:
        """Print the title message."""
        message = self._format_message(self.title)
        print(message, file=sys.stdout)
        sys.stdout.flush()

    def _print_message(self, message: str) -> None:
        """Print a message to console."""
        if self._previous_message and self.update_inplace:
            # Use backspace characters to overwrite previous message
            backspaces = '\b' * (len(self._previous_message) + 1)
            print(f'{backspaces}\n{message}', end='', file=sys.stdout)
        else:
            print(f'\n{message}', end='', file=sys.stdout)

        sys.stdout.flush()
        self._previous_message = message

    def _update_progress_message(self, core_message: str) -> None:
        """Update progress message with time estimates."""
        message = core_message

        # Add remaining time estimate
        if self.display_remaining_time and self._is_initialized:
            remaining_time = self._estimate_remaining_time()
            if remaining_time is not None and remaining_time < float('inf'):
                remaining_str = self._format_time_duration(remaining_time)
                message = f"{message}. Remaining time: {remaining_str}"

        # Format with timestamp/indentation
        message = self._format_message(message)
        self._print_message(message)

    def _format_message(self, core_message: str) -> str:
        """Format a message with indentation and timestamp."""
        # Apply indentation
        indentation = ' ' * self.indent_size
        message = f"{indentation}{core_message}"

        # Add timestamp
        if self.show_timestamp:
            timestamp = datetime.now().strftime(self.timestamp_format)
            message = f"{timestamp}: {message}"

        return message


class TqdmProgressMonitor(ProgressMonitor):
    """
    Progress monitor using tqdm for nice progress bars.

    Requires: pip install tqdm

    Example:
        >>> try:
        ...     from ndi.gui import TqdmProgressMonitor
        ...     tracker = ProgressTracker()
        ...     monitor = TqdmProgressMonitor("Processing", tracker=tracker)
        ...     for i in range(100):
        ...         tracker.update_progress(i / 100, f"Item {i}")
        ... except ImportError:
        ...     print("tqdm not available, falling back to ConsoleProgressMonitor")
    """

    def __init__(self,
                 title: str = "In progress...",
                 tracker: Optional[ProgressTracker] = None):
        """
        Initialize TqdmProgressMonitor.

        Args:
            title: Title/description of the operation
            tracker: ProgressTracker instance

        Raises:
            ImportError: If tqdm is not installed
        """
        try:
            from tqdm import tqdm
        except ImportError:
            raise ImportError(
                "tqdm is required for TqdmProgressMonitor. "
                "Install with: pip install tqdm"
            )

        super().__init__(title, tracker, display_remaining_time=True)

        self._tqdm = tqdm(total=100, desc=title, unit='%', ncols=80)

    def update_progress_display(self) -> None:
        """Update the tqdm progress bar."""
        progress_pct = int(self.tracker.fraction_complete * 100)
        current = self._tqdm.n
        self._tqdm.update(progress_pct - current)

        if self.tracker.message:
            self._tqdm.set_postfix_str(self.tracker.message)

    def update_message(self, message: str) -> None:
        """Update the status message."""
        self._tqdm.set_postfix_str(message)

    def finish(self) -> None:
        """Finish and close the progress bar."""
        self._tqdm.close()

    def __del__(self):
        """Cleanup tqdm on deletion."""
        if hasattr(self, '_tqdm'):
            self._tqdm.close()
