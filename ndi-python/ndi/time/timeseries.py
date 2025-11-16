"""
NDI TimeSeries - Abstract class for managing time series data.

This module provides the TimeSeries mixin class that can be added to
any class that needs to provide time series data access.
"""

from typing import Tuple, List, Union, Optional, Any
from abc import ABC, abstractmethod
import numpy as np


class TimeSeries(ABC):
    """
    TimeSeries mixin - Provides time series data access methods.

    This is an abstract mixin class that defines methods for objects
    that deal with time series data. Classes that inherit from this
    must implement the readtimeseries() method.

    Methods:
        readtimeseries: Read time series data (abstract - must implement)
        samplerate: Get sample rate for an epoch
        times2samples: Convert times to sample indices
        samples2times: Convert sample indices to times

    Usage:
        class MyTimeSeries(TimeSeries, SomeBaseClass):
            def readtimeseries(self, timeref_or_epoch, t0, t1):
                # Implementation here
                ...
    """

    @abstractmethod
    def readtimeseries(self, timeref_or_epoch: Union[Any, int],
                      t0: float, t1: float) -> Tuple[np.ndarray, Union[np.ndarray, dict], Any]:
        """
        Read time series data from this object.

        Args:
            timeref_or_epoch: Either a TimeReference object or an epoch number
            t0: Start time
            t1: End time

        Returns:
            Tuple of (data, t, timeref) where:
            - data: The time series data (numpy array)
            - t: Time information (array or dict of arrays)
            - timeref: The time reference used

        Notes:
            TIMEREF_OR_EPOCH can be:
            - An ndi.time.timereference object indicating the time reference
            - A single number indicating the epoch number

            DATA is the data for the object.
            T is time information, in units of TIMEREF if it's a timereference
              object or in units of the epoch if an epoch number is passed.
            TIMEREF is the time reference that was used.

        Abstract method - must be implemented by subclasses.
        """
        pass

    def samplerate(self, epoch: Union[int, str]) -> float:
        """
        Return the sample rate of timeseries data.

        Args:
            epoch: Epoch number or epoch ID

        Returns:
            Sample rate in Hz, or -1 if not regularly sampled

        Notes:
            Base implementation returns -1 (not regularly sampled).
            Subclasses should override if they support regular sampling.
        """
        return -1.0

    def times2samples(self, epoch: Union[int, str], times: Union[float, np.ndarray]) -> Union[int, np.ndarray]:
        """
        Convert from timeseries time to sample numbers.

        Args:
            epoch: Epoch number or epoch ID
            times: Time values to convert

        Returns:
            Sample index numbers (1-indexed, first sample is 1)

        Notes:
            The TIMES requested might be out of bounds of the epoch;
            no checking is performed.

            Infinite times are handled:
            - -inf maps to sample 1
            - +inf maps to last sample in epoch

            This only works for regularly sampled data (samplerate > 0).
        """
        sr = self.samplerate(epoch)

        if sr <= 0:
            # Not regularly sampled - need subclass override
            return None

        # Get epoch timing information
        if hasattr(self, 'epochtableentry'):
            et = self.epochtableentry(epoch)
            t0_t1 = et.get('t0_t1', [[0, 0]])
            if isinstance(t0_t1, list) and len(t0_t1) > 0:
                t0 = t0_t1[0][0]
                t1 = t0_t1[0][1]
            else:
                return None
        else:
            return None

        # Convert times to numpy array if needed
        if not isinstance(times, np.ndarray):
            times = np.array([times]) if not hasattr(times, '__iter__') else np.array(times)
            scalar_input = True
        else:
            scalar_input = False

        # Calculate samples (1-indexed)
        samples = 1 + np.round((times - t0) * sr).astype(int)

        # Handle infinite times
        samples[np.isinf(times) & (times < 0)] = 1
        samples[np.isinf(times) & (times > 0)] = 1 + int(sr * (t1 - t0))

        if scalar_input:
            return int(samples[0])
        return samples

    def samples2times(self, epoch: Union[int, str], samples: Union[int, np.ndarray]) -> Union[float, np.ndarray]:
        """
        Convert from sample numbers to timeseries time.

        Args:
            epoch: Epoch number or epoch ID
            samples: Sample index numbers (1-indexed)

        Returns:
            Time values

        Notes:
            The first sample in the epoch is 1.
            Samples might be out of bounds; no checking is performed.

            This only works for regularly sampled data (samplerate > 0).
        """
        sr = self.samplerate(epoch)

        if sr <= 0:
            # Not regularly sampled - need subclass override
            return None

        # Get epoch timing information
        if hasattr(self, 'epochtableentry'):
            et = self.epochtableentry(epoch)
            t0_t1 = et.get('t0_t1', [[0, 0]])
            if isinstance(t0_t1, list) and len(t0_t1) > 0:
                t0 = t0_t1[0][0]
            else:
                return None
        else:
            return None

        # Convert samples to numpy array if needed
        if not isinstance(samples, np.ndarray):
            samples = np.array([samples]) if not hasattr(samples, '__iter__') else np.array(samples)
            scalar_input = True
        else:
            scalar_input = False

        # Calculate times (samples are 1-indexed)
        times = t0 + (samples - 1) / sr

        if scalar_input:
            return float(times[0])
        return times
