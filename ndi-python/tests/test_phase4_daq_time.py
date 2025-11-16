"""
Test Phase 4: DAQ & Time Systems

Tests for time conversion utilities and DAQ system string parsing.
"""

import pytest
import numpy as np
from ndi.time.fun import samples2times, times2samples
from ndi.daq import DAQSystemString


class TestSamples2Times:
    """Test sample index to time conversion."""

    def test_basic_conversion(self):
        """Test basic sample to time conversion."""
        # Sample 1 at t=0, sample rate 1000 Hz
        times = samples2times([1, 1001, 2001], (0.0, 10.0), 1000.0)
        expected = np.array([0.0, 1.0, 2.0])
        np.testing.assert_array_almost_equal(times, expected)

    def test_single_sample(self):
        """Test single sample conversion."""
        time = samples2times(1, (0.0, 10.0), 1000.0)
        assert time[0] == 0.0

        time = samples2times(101, (5.0, 15.0), 100.0)
        assert time[0] == 6.0

    def test_numpy_array_input(self):
        """Test numpy array input."""
        samples = np.array([1, 11, 21, 31])
        times = samples2times(samples, (0.0, 1.0), 10.0)
        expected = np.array([0.0, 1.0, 2.0, 3.0])
        np.testing.assert_array_almost_equal(times, expected)

    def test_negative_infinity(self):
        """Test negative infinity maps to t0."""
        times = samples2times([-np.inf, 1, 100], (5.0, 10.0), 100.0)
        assert times[0] == 5.0  # t0
        assert times[1] == 5.0  # sample 1 at t0
        np.testing.assert_almost_equal(times[2], 5.99)

    def test_positive_infinity(self):
        """Test positive infinity maps to t1."""
        times = samples2times([1, 100, np.inf], (0.0, 10.0), 100.0)
        assert times[0] == 0.0
        assert times[2] == 10.0  # t1

    def test_non_zero_t0(self):
        """Test with non-zero start time."""
        times = samples2times([1, 501], (10.0, 20.0), 100.0)
        expected = np.array([10.0, 15.0])
        np.testing.assert_array_almost_equal(times, expected)

    def test_fractional_samples(self):
        """Test fractional sample indices."""
        times = samples2times([1.5, 2.5], (0.0, 10.0), 1000.0)
        expected = np.array([0.0005, 0.0015])
        np.testing.assert_array_almost_equal(times, expected)


class TestTimes2Samples:
    """Test time to sample index conversion."""

    def test_basic_conversion(self):
        """Test basic time to sample conversion."""
        # Times at 0, 1, 2 seconds with 1000 Hz sampling
        samples = times2samples([0.0, 1.0, 2.0], (0.0, 10.0), 1000.0)
        expected = np.array([1, 1001, 2001], dtype=int)
        np.testing.assert_array_equal(samples, expected)

    def test_single_time(self):
        """Test single time conversion."""
        sample = times2samples(0.0, (0.0, 10.0), 1000.0)
        assert sample[0] == 1

        sample = times2samples(6.0, (5.0, 15.0), 100.0)
        assert sample[0] == 101

    def test_numpy_array_input(self):
        """Test numpy array input."""
        times = np.array([0.0, 1.0, 2.0, 3.0])
        samples = times2samples(times, (0.0, 10.0), 10.0)
        expected = np.array([1, 11, 21, 31], dtype=int)
        np.testing.assert_array_equal(samples, expected)

    def test_negative_infinity(self):
        """Test negative infinity maps to sample 1."""
        samples = times2samples([-np.inf, 0.0, 1.0], (0.0, 10.0), 100.0)
        assert samples[0] == 1
        assert samples[1] == 1

    def test_positive_infinity(self):
        """Test positive infinity maps to last sample."""
        samples = times2samples([0.0, 1.0, np.inf], (0.0, 10.0), 100.0)
        # Last sample = 1 + samplerate * (t1 - t0) = 1 + 100 * 10 = 1001
        assert samples[0] == 1
        assert samples[2] == 1001

    def test_non_zero_t0(self):
        """Test with non-zero start time."""
        samples = times2samples([10.0, 15.0], (10.0, 20.0), 100.0)
        expected = np.array([1, 501], dtype=int)
        np.testing.assert_array_equal(samples, expected)

    def test_rounding(self):
        """Test proper rounding of fractional samples."""
        # 0.005 seconds at 1000 Hz = sample 6 (1 + round(5))
        samples = times2samples([0.005, 0.0054, 0.0045], (0.0, 10.0), 1000.0)
        expected = np.array([6, 6, 5], dtype=int)
        np.testing.assert_array_equal(samples, expected)

    def test_roundtrip_conversion(self):
        """Test that samples -> times -> samples gives same result."""
        original_samples = np.array([1, 100, 500, 1000])
        t0_t1 = (0.0, 10.0)
        samplerate = 100.0

        times = samples2times(original_samples, t0_t1, samplerate)
        recovered_samples = times2samples(times, t0_t1, samplerate)

        np.testing.assert_array_equal(original_samples, recovered_samples)


class TestDAQSystemString:
    """Test DAQ system device string parsing and generation."""

    def test_parse_simple_string(self):
        """Test parsing simple device string."""
        dss = DAQSystemString('mydevice:ai1-5,7,23')
        assert dss.devicename == 'mydevice'
        assert dss.channeltype == ['ai'] * 7
        assert dss.channellist == [1, 2, 3, 4, 5, 7, 23]

    def test_parse_multiple_channel_types(self):
        """Test parsing string with multiple channel types."""
        dss = DAQSystemString('dev1:ai1-3;di5,7')
        assert dss.devicename == 'dev1'
        assert dss.channeltype == ['ai', 'ai', 'ai', 'di', 'di']
        assert dss.channellist == [1, 2, 3, 5, 7]

    def test_build_from_components(self):
        """Test building from components."""
        dss = DAQSystemString('mydevice', ['ai']*7, [1, 2, 3, 4, 5, 10, 17])
        assert dss.devicename == 'mydevice'
        assert len(dss.channeltype) == 7
        assert len(dss.channellist) == 7

    def test_devicestring_generation(self):
        """Test device string generation."""
        dss = DAQSystemString('mydevice', ['ai']*7, [1, 2, 3, 4, 5, 10, 17])
        result = dss.devicestring()
        assert result == 'mydevice:ai1-5,10,17'

    def test_devicestring_generation_multiple_types(self):
        """Test device string generation with multiple channel types."""
        dss = DAQSystemString(
            'dev1',
            ['ai', 'ai', 'ai', 'di', 'di', 'di'],
            [1, 2, 3, 10, 11, 12]
        )
        result = dss.devicestring()
        assert result == 'dev1:ai1-3;di10-12'

    def test_roundtrip_parsing(self):
        """Test parsing and regenerating gives equivalent result."""
        original = 'mydevice:ai1-5,10,17;di20-22'
        dss = DAQSystemString(original)
        regenerated = dss.devicestring()

        # Parse both and compare components
        dss1 = DAQSystemString(original)
        dss2 = DAQSystemString(regenerated)

        assert dss1.devicename == dss2.devicename
        assert dss1.channeltype == dss2.channeltype
        assert dss1.channellist == dss2.channellist

    def test_channel_sequence_parsing(self):
        """Test channel sequence parsing with various formats."""
        # Single range
        dss = DAQSystemString('dev:ai1-5')
        assert dss.channellist == [1, 2, 3, 4, 5]

        # Multiple ranges
        dss = DAQSystemString('dev:ai1-3,10-12')
        assert dss.channellist == [1, 2, 3, 10, 11, 12]

        # Mixed ranges and singles
        dss = DAQSystemString('dev:ai1-3,7,10-11')
        assert dss.channellist == [1, 2, 3, 7, 10, 11]

    def test_channel_sequence_formatting(self):
        """Test channel sequence formatting with ranges."""
        # Consecutive channels become range
        dss = DAQSystemString('dev', ['ai']*5, [1, 2, 3, 4, 5])
        assert dss.devicestring() == 'dev:ai1-5'

        # Non-consecutive stay separate
        dss = DAQSystemString('dev', ['ai']*3, [1, 5, 10])
        assert dss.devicestring() == 'dev:ai1,5,10'

        # Two consecutive numbers still use range
        dss = DAQSystemString('dev', ['ai']*2, [5, 6])
        assert dss.devicestring() == 'dev:ai5-6'

    def test_whitespace_handling(self):
        """Test that whitespace is ignored."""
        dss = DAQSystemString('mydevice : ai 1-5 , 10 , 17')
        assert dss.channellist == [1, 2, 3, 4, 5, 10, 17]

    def test_missing_colon_error(self):
        """Test error when colon missing."""
        with pytest.raises(ValueError, match="must contain ':'"):
            DAQSystemString('mydevice')

    def test_length_mismatch_error(self):
        """Test error when channeltype and channellist lengths don't match."""
        with pytest.raises(ValueError, match="same length"):
            DAQSystemString('dev', ['ai', 'ai'], [1, 2, 3])

    def test_invalid_range_error(self):
        """Test error on invalid range."""
        with pytest.raises(ValueError, match="Invalid range"):
            DAQSystemString('dev:ai1-2-3')

    def test_no_numbers_error(self):
        """Test error when no numbers in segment."""
        with pytest.raises(ValueError, match="No numbers found"):
            DAQSystemString('dev:ai')

    def test_empty_channel_list(self):
        """Test handling of empty channel list."""
        dss = DAQSystemString('dev', [], [])
        assert dss.devicestring() == 'dev:'

    def test_repr_and_str(self):
        """Test string representations."""
        dss = DAQSystemString('dev:ai1-3')
        assert str(dss) == 'dev:ai1-3'
        assert repr(dss) == "DAQSystemString('dev:ai1-3')"

    def test_equality(self):
        """Test equality comparison."""
        dss1 = DAQSystemString('dev:ai1-3')
        dss2 = DAQSystemString('dev', ['ai', 'ai', 'ai'], [1, 2, 3])
        dss3 = DAQSystemString('dev:ai1-5')

        assert dss1 == dss2
        assert dss1 != dss3
        assert dss1 != "not a DAQSystemString"

    def test_complex_real_world_example(self):
        """Test complex real-world device string."""
        # Multi-channel recording with different types
        devstr = 'recording_device:ai0-31;di0-7;ao0-3'
        dss = DAQSystemString(devstr)

        assert dss.devicename == 'recording_device'
        assert len(dss.channeltype) == 32 + 8 + 4
        assert dss.channellist[:32] == list(range(32))
        assert dss.channellist[32:40] == list(range(8))
        assert dss.channellist[40:] == list(range(4))

        # Regenerate and verify
        regenerated = dss.devicestring()
        dss2 = DAQSystemString(regenerated)
        assert dss == dss2


class TestPhase4Integration:
    """Integration tests combining time and DAQ utilities."""

    def test_daq_with_time_conversion(self):
        """Test using DAQ string with time conversions."""
        # Parse DAQ string to get channel list
        dss = DAQSystemString('neuraldaq:ai0-15')
        num_channels = len(dss.channellist)
        assert num_channels == 16

        # Convert sample times for these channels
        sample_indices = [1, 1001, 2001]
        times = samples2times(sample_indices, (0.0, 10.0), 1000.0)

        # Verify we can work with both
        assert len(times) == len(sample_indices)
        assert dss.channeltype[0] == 'ai'

    def test_multiple_devices_time_sync(self):
        """Test time conversion for multiple synchronized devices."""
        # Two devices recorded simultaneously
        dev1 = DAQSystemString('neural:ai0-31')
        dev2 = DAQSystemString('behavioral:di0-7')

        # Both start at same time, different sample rates
        t0_t1 = (0.0, 60.0)  # 60 second recording

        # Neural at 30kHz, behavioral at 1kHz
        neural_times = samples2times([1, 30001, 60001], t0_t1, 30000.0)
        behavior_times = samples2times([1, 1001, 2001], t0_t1, 1000.0)

        # First sample at t=0 for both
        assert neural_times[0] == 0.0
        assert behavior_times[0] == 0.0

        # Second samples at t=1 for both
        np.testing.assert_almost_equal(neural_times[1], 1.0)
        np.testing.assert_almost_equal(behavior_times[1], 1.0)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
