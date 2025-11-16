"""
Logging infrastructure for NDI.

This module provides centralized logging functionality for NDI with
separate log files for system, debug, and error messages.

Ported from MATLAB: ndi.common.getLogger concept
"""

import os
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional


class Logger:
    """
    NDI logging system with separate logs for system, debug, and errors.

    Attributes:
        system_logfile: Path to system log file
        debug_logfile: Path to debug log file
        error_logfile: Path to error log file
    """

    _instance: Optional['Logger'] = None

    def __init__(self, log_dir: Optional[str] = None):
        """
        Initialize NDI logger.

        Args:
            log_dir: Directory for log files (default: ~/.ndi/logs/)
        """
        if log_dir is None:
            log_dir = os.path.join(str(Path.home()), '.ndi', 'logs')

        os.makedirs(log_dir, exist_ok=True)

        # Create log file paths
        timestamp = datetime.now().strftime('%Y%m%d')
        self.system_logfile = os.path.join(log_dir, f'ndi_system_{timestamp}.log')
        self.debug_logfile = os.path.join(log_dir, f'ndi_debug_{timestamp}.log')
        self.error_logfile = os.path.join(log_dir, f'ndi_error_{timestamp}.log')

        # Set up Python loggers
        self._setup_loggers()

    def _setup_loggers(self):
        """Set up Python logging handlers for each log type."""
        # System logger
        self.system_logger = logging.getLogger('ndi.system')
        self.system_logger.setLevel(logging.INFO)
        self._add_file_handler(self.system_logger, self.system_logfile)

        # Debug logger
        self.debug_logger = logging.getLogger('ndi.debug')
        self.debug_logger.setLevel(logging.DEBUG)
        self._add_file_handler(self.debug_logger, self.debug_logfile)

        # Error logger
        self.error_logger = logging.getLogger('ndi.error')
        self.error_logger.setLevel(logging.ERROR)
        self._add_file_handler(self.error_logger, self.error_logfile)

    def _add_file_handler(self, logger: logging.Logger, filename: str):
        """Add file handler to logger."""
        handler = logging.FileHandler(filename)
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    def log_system(self, message: str):
        """Log a system message."""
        self.system_logger.info(message)

    def log_debug(self, message: str):
        """Log a debug message."""
        self.debug_logger.debug(message)

    def log_error(self, message: str):
        """Log an error message."""
        self.error_logger.error(message)


def get_logger() -> Logger:
    """
    Get the singleton NDI logger instance.

    Returns:
        Logger: The global NDI logger

    Example:
        >>> from ndi.common import get_logger
        >>> logger = get_logger()
        >>> logger.log_system('NDI initialized')
        >>> logger.log_error('An error occurred')
    """
    if Logger._instance is None:
        Logger._instance = Logger()
    return Logger._instance
