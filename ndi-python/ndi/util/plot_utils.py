"""
Plotting utilities for NDI.
"""

import warnings
from typing import Optional, Tuple


def check_matplotlib() -> bool:
    """Check if matplotlib is available."""
    try:
        import matplotlib
        return True
    except ImportError:
        return False


def setup_plot_style(style: str = 'default') -> None:
    """
    Set up matplotlib plot style.

    Args:
        style: Style name ('default', 'seaborn', 'ggplot', etc.)
    """
    if not check_matplotlib():
        warnings.warn("matplotlib not available")
        return

    import matplotlib.pyplot as plt

    try:
        plt.style.use(style)
    except Exception:
        warnings.warn(f"Style '{style}' not available, using default")


def save_figure(filename: str, dpi: int = 300, bbox_inches: str = 'tight') -> None:
    """
    Save current matplotlib figure.

    Args:
        filename: Output filename
        dpi: Resolution in dots per inch
        bbox_inches: Bounding box setting
    """
    if not check_matplotlib():
        raise ImportError("matplotlib required for saving figures")

    import matplotlib.pyplot as plt
    plt.savefig(filename, dpi=dpi, bbox_inches=bbox_inches)


def create_subplot_grid(n_plots: int) -> Tuple[int, int]:
    """
    Calculate optimal subplot grid dimensions.

    Args:
        n_plots: Number of plots

    Returns:
        Tuple of (rows, cols) for subplot grid
    """
    import math

    if n_plots == 1:
        return (1, 1)
    elif n_plots == 2:
        return (1, 2)
    else:
        cols = math.ceil(math.sqrt(n_plots))
        rows = math.ceil(n_plots / cols)
        return (rows, cols)
