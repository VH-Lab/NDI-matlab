"""
Open NDI debug log in terminal.

Ported from MATLAB: src/ndi/+ndi/+fun/debuglog.m
"""

from ndi.common import get_logger
from .console import console


def debuglog() -> None:
    """
    Open the NDI debug log in a terminal window.

    Opens a live-updating terminal window showing the NDI debug log file.

    Example:
        >>> from ndi.fun import debuglog
        >>> debuglog()  # Opens terminal with debug log

    Notes:
        - Platform-specific terminal handling (macOS, Linux, Windows)
        - Log file location managed by ndi.common.Logger
        - Displays live updates (tail -f style)
    """
    logger = get_logger()
    console(logger.debug_logfile)
