"""
Mock DAQ System - A simple mock DAQ system for testing.

This module provides a mock DAQ system implementation for testing DAQ-related
functionality without requiring real hardware or data files.
"""

from typing import List, Dict, Any, Optional
import numpy as np


class MockDAQSystem:
    """
    Mock DAQ system for testing purposes.

    Simulates a simple DAQ system with predefined behavior and fake data.

    Example:
        >>> from ndi.mock.daqsystem import MockDAQSystem
        >>> daq = MockDAQSystem('test_daq')
        >>> daq.name
        'test_daq'
        >>> data = daq.read_data(0, 1.0)
        >>> data.shape[0] > 0
        True
    """

    def __init__(
        self,
        name: str = 'mock_daq',
        num_channels: int = 1,
        sample_rate: float = 1000.0
    ):
        """
        Create a mock DAQ system.

        Args:
            name: DAQ system name
            num_channels: Number of data channels
            sample_rate: Sample rate in Hz

        Example:
            >>> daq = MockDAQSystem('my_daq', num_channels=4, sample_rate=2000)
            >>> daq.sample_rate
            2000.0
        """
        self.name = name
        self.num_channels = num_channels
        self.sample_rate = sample_rate
        self.epochs = [{'number': 0, 'duration': 10.0}]  # Mock epoch

    def read_data(
        self,
        channel: int,
        duration: float,
        start_time: float = 0.0
    ) -> np.ndarray:
        """
        Read mock data from a channel.

        Args:
            channel: Channel number
            duration: Duration in seconds
            start_time: Start time in seconds

        Returns:
            Array of mock data (random noise)

        Example:
            >>> daq = MockDAQSystem('test')
            >>> data = daq.read_data(0, 1.0)
            >>> len(data) == 1000  # 1 second at 1000 Hz
            True
        """
        if channel < 0 or channel >= self.num_channels:
            raise ValueError(f"Invalid channel {channel}")

        num_samples = int(duration * self.sample_rate)

        # Return random noise as mock data
        return np.random.randn(num_samples) * 0.1

    def get_epochs(self) -> List[Dict[str, Any]]:
        """
        Get list of available epochs.

        Returns:
            List of epoch dicts

        Example:
            >>> daq = MockDAQSystem('test')
            >>> epochs = daq.get_epochs()
            >>> len(epochs) > 0
            True
        """
        return self.epochs

    def add_epoch(self, epoch_number: int, duration: float) -> None:
        """
        Add a mock epoch.

        Args:
            epoch_number: Epoch number
            duration: Epoch duration in seconds

        Example:
            >>> daq = MockDAQSystem('test')
            >>> daq.add_epoch(1, 5.0)
            >>> len(daq.epochs)
            2
        """
        self.epochs.append({
            'number': epoch_number,
            'duration': duration
        })

    def __repr__(self) -> str:
        """String representation."""
        return (
            f"MockDAQSystem(name='{self.name}', "
            f"channels={self.num_channels}, "
            f"rate={self.sample_rate}Hz, "
            f"epochs={len(self.epochs)})"
        )
