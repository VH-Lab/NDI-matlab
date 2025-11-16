"""
Open NDI error log in terminal.

Ported from MATLAB: src/ndi/+ndi/+fun/errlog.m
"""

from ndi.common import get_logger
from .console import console


def errlog() -> None:
    """
    Open the NDI error log in a terminal window.

    Opens a live-updating terminal window showing the NDI error log file.

    Example:
        >>> from ndi.fun import errlog
        >>> errlog()  # Opens terminal with error log

    Notes:
        - Platform-specific terminal handling (macOS, Linux, Windows)
        - Log file location managed by ndi.common.Logger
        - Displays live updates (tail -f style)
    """
    logger = get_logger()
    console(logger.error_logfile)
