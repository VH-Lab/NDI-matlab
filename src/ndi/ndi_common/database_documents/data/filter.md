# filter

The `filter` document class stores information about digital filters applied to data.

## Fields

### type

The type of the filter. Can be one of:
* 'bandpass'
* 'low'
* 'high'
* 'none'

### algorithm

The algorithm used for the filter. Can be one of:
* 'chebyshev_1'
* 'chebyshev_2'
* 'butterworth'
* 'bessel'
* 'elliptic'
* 'none'

### parameters

A structure containing the specific parameters of the filter.

* **sampleFrequency** (double): The sample frequency of the data to be filtered.
* **order** (integer): The filter order.
* **filterFrequency** (double vector): The frequencies of the filter. A single value for low- or high-pass filters, two values for bandpass filters, or 0 values for no filter.
* **passbandRipple** (double): Amount of ripple in the pass band (default 0.8).
* **stopbandAttenuation** (double): Amount of attenuation in the stop band.
