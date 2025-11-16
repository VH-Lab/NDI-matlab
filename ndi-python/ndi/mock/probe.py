"""
Mock Probe - A simple mock probe for testing.

This module provides a mock probe implementation for testing probe-related
functionality without requiring real hardware definitions.
"""

from typing import List, Dict, Any, Optional


class MockProbe:
    """
    Mock probe for testing purposes.

    Simulates a simple probe with predefined channels and properties.

    Example:
        >>> from ndi.mock.probe import MockProbe
        >>> probe = MockProbe('test_probe', num_channels=4)
        >>> probe.name
        'test_probe'
        >>> len(probe.channels)
        4
    """

    def __init__(
        self,
        name: str = 'mock_probe',
        num_channels: int = 1,
        probe_type: str = 'electrode'
    ):
        """
        Create a mock probe.

        Args:
            name: Probe name
            num_channels: Number of channels
            probe_type: Type of probe (electrode, optical, etc.)

        Example:
            >>> probe = MockProbe('my_probe', num_channels=8)
            >>> probe.num_channels
            8
        """
        self.name = name
        self.num_channels = num_channels
        self.probe_type = probe_type

        # Create mock channels
        self.channels = []
        for i in range(num_channels):
            self.channels.append({
                'number': i,
                'name': f'channel_{i}',
                'type': probe_type,
                'reference': ''
            })

    def get_channel(self, channel_num: int) -> Optional[Dict[str, Any]]:
        """
        Get information about a channel.

        Args:
            channel_num: Channel number

        Returns:
            Channel dict if found, None otherwise

        Example:
            >>> probe = MockProbe('test', num_channels=4)
            >>> ch = probe.get_channel(0)
            >>> ch['name']
            'channel_0'
        """
        if 0 <= channel_num < len(self.channels):
            return self.channels[channel_num]
        return None

    def __repr__(self) -> str:
        """String representation."""
        return (
            f"MockProbe(name='{self.name}', "
            f"type='{self.probe_type}', "
            f"channels={self.num_channels})"
        )
