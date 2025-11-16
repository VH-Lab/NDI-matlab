"""
Console/terminal window utilities for NDI log files.

This module provides functionality to open terminal windows displaying
log files with live updates.

Ported from MATLAB: src/ndi/+ndi/+fun/console.m
"""

import os
import sys
import platform
import subprocess
import tempfile


def console(filename: str) -> None:
    """
    Pop up an external terminal window that displays a log file.

    Opens a console/terminal window that displays and follows (tail -f)
    a log file in real-time.

    Args:
        filename: Path to the log file to display

    Raises:
        OSError: If platform is not supported or command fails
        FileNotFoundError: If log file doesn't exist

    Example:
        >>> console('/path/to/logfile.log')
        # Opens terminal window following the log file

    Notes:
        - macOS: Uses osascript to open Terminal.app
        - Linux: Uses xterm or gnome-terminal
        - Windows: Uses cmd with 'type' and PowerShell
        - File is followed live (like tail -f)
    """
    if not os.path.exists(filename):
        raise FileNotFoundError(f"Log file not found: {filename}")

    system = platform.system()

    if system == 'Darwin':  # macOS
        _console_macos(filename)
    elif system == 'Linux':
        _console_linux(filename)
    elif system == 'Windows':
        _console_windows(filename)
    else:
        raise OSError(f"Platform '{system}' not supported for console viewing")


def _console_macos(filename: str) -> None:
    """Open console on macOS using Terminal.app."""
    # Create AppleScript to open Terminal with tail command
    with tempfile.NamedTemporaryFile(mode='w', suffix='.scpt', delete=False) as f:
        script = f"""tell application "Terminal"
    activate
    do script "tail -f {filename}"
end tell
"""
        f.write(script)
        script_file = f.name

    try:
        subprocess.run(['osascript', script_file], check=True)
    finally:
        try:
            os.unlink(script_file)
        except:
            pass


def _console_linux(filename: str) -> None:
    """Open console on Linux using available terminal."""
    # Try different terminal emulators in order of preference
    terminals = [
        ['gnome-terminal', '--', 'tail', '-f', filename],
        ['xterm', '-e', 'tail', '-f', filename],
        ['konsole', '-e', 'tail', '-f', filename],
        ['xfce4-terminal', '-e', f'tail -f {filename}'],
    ]

    for term_cmd in terminals:
        try:
            subprocess.Popen(term_cmd)
            return
        except FileNotFoundError:
            continue

    raise OSError("No supported terminal emulator found (tried: gnome-terminal, xterm, konsole, xfce4-terminal)")


def _console_windows(filename: str) -> None:
    """Open console on Windows using cmd or PowerShell."""
    try:
        # Try PowerShell with Get-Content -Wait (equivalent to tail -f)
        cmd = ['powershell', '-Command', f'Get-Content -Path "{filename}" -Wait']
        subprocess.Popen(cmd, creationflags=subprocess.CREATE_NEW_CONSOLE)
    except Exception:
        # Fallback to cmd (no live follow, just shows current content)
        cmd = ['cmd', '/c', 'start', 'cmd', '/k', 'type', filename]
        subprocess.Popen(cmd)
