"""
Tutorial 02: DAQ Systems and Data Reading.

This tutorial demonstrates working with data acquisition (DAQ) systems:
- Creating and configuring DAQ systems
- Managing epochs and channels
- Reading data from acquisitions
- Working with probes and elements

Note: This is a code template. For actual data reading, you'll need
real data files and appropriate DAQ readers.
"""

import tempfile
import numpy as np

from ndi.session import SessionDir
from ndi.query import Query
from ndi.mock import MockDAQSystem, MockProbe


def tutorial_daq():
    """
    Demonstrate DAQ system operations.

    This example shows how to:
    1. Create a session for DAQ data
    2. Set up mock DAQ systems (in practice, use real readers)
    3. Configure probes/elements
    4. Work with epochs
    5. Read data (simulated in this example)
    """

    print("=" * 70)
    print("Tutorial 02: DAQ Systems and Data Reading")
    print("=" * 70)

    # Step 1: Create a session
    session_path = tempfile.mkdtemp(prefix='ndi_daq_tutorial_')
    print(f"\nStep 1: Creating session at: {session_path}")

    session = SessionDir(session_path, 'daq_tutorial')
    print(f"Session ID: {session.id()}")

    # Step 2: Create a mock DAQ system
    # In practice, you would use real DAQ system readers like:
    # - ndi.daq.system.mfdaq for multi-file DAQ
    # - Specific readers for your acquisition format
    print("\nStep 2: Setting up DAQ system")

    # Create a mock DAQ system with 4 channels at 2000 Hz
    mock_daq = MockDAQSystem(
        name='test_acquisition',
        num_channels=4,
        sample_rate=2000.0
    )

    print(f"DAQ System: {mock_daq.name}")
    print(f"Channels: {mock_daq.num_channels}")
    print(f"Sample rate: {mock_daq.sample_rate} Hz")

    # Step 3: Configure a probe
    # Probes define the physical recording device
    print("\nStep 3: Configuring probe")

    probe = MockProbe(
        name='electrode_array',
        num_channels=4,
        probe_type='electrode'
    )

    print(f"Probe: {probe.name}")
    print(f"Type: {probe.probe_type}")
    print(f"Channels: {len(probe.channels)}")

    # Step 4: Work with epochs
    # Epochs represent distinct recording periods
    print("\nStep 4: Managing epochs")

    epochs = mock_daq.get_epochs()
    print(f"Available epochs: {len(epochs)}")

    # Add a new epoch
    mock_daq.add_epoch(epoch_number=1, duration=10.0)
    print(f"Added epoch 1 (10 seconds)")

    # Step 5: Read data
    # In practice, this would read from actual data files
    print("\nStep 5: Reading data")

    # Read 1 second of data from channel 0
    data = mock_daq.read_data(channel=0, duration=1.0, start_time=0.0)

    print(f"Data shape: {data.shape}")
    print(f"Data statistics:")
    print(f"  Mean: {np.mean(data):.4f}")
    print(f"  Std: {np.std(data):.4f}")
    print(f"  Min: {np.min(data):.4f}")
    print(f"  Max: {np.max(data):.4f}")

    # Step 6: Read from multiple channels
    print("\nStep 6: Multi-channel data")

    all_data = []
    for ch in range(mock_daq.num_channels):
        ch_data = mock_daq.read_data(channel=ch, duration=0.5)
        all_data.append(ch_data)

    all_data = np.array(all_data)  # Shape: (channels, samples)
    print(f"Multi-channel data shape: {all_data.shape}")

    # Step 7: Example data processing
    print("\nStep 7: Simple data processing")

    # Calculate average across channels
    avg_signal = np.mean(all_data, axis=0)
    print(f"Average signal shape: {avg_signal.shape}")

    # Calculate power in each channel
    power_per_channel = np.mean(all_data ** 2, axis=1)
    print(f"Power per channel: {power_per_channel}")

    print("\n" + "=" * 70)
    print("Tutorial complete!")
    print("\nIn practice:")
    print("  - Use real DAQ readers (ndi.daq.system.mfdaq, etc.)")
    print("  - Configure actual probes matching your hardware")
    print("  - Add DAQ systems to sessions with session.daqsystem_add()")
    print("  - Read data using DAQ system methods")
    print("=" * 70)

    return session, session_path


def main():
    """Run the tutorial."""
    session, path = tutorial_daq()

    # Clean up (uncomment if you want to remove the temporary session)
    # import shutil
    # shutil.rmtree(path, ignore_errors=True)
    # print(f"\nCleaned up session at {path}")


if __name__ == '__main__':
    main()
