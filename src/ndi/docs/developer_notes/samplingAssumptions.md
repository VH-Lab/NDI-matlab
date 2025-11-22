| Function Name | Line Number | Line of Code | Comment | Needs updating | Fixed |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ndi.daq.reader.mfdaq.ingest_epochfiles` | 784 | `S1 = 1+ (t0t1{1}(end) - t0t1{1}(1)) * unique(sample_rates_here_unique);` | Calculates total samples from duration and rate, assuming constant rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.ingest_epochfiles` | 811 | `S1 = 1+(t0t1{1}(end) - t0t1{1}(1)) * unique(sample_rates_here_unique);` | Calculates total samples from duration and rate, assuming constant rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.readchannels_epochsamples_ingested` | 200 | `absolute_beginning = ndi.time.fun.times2samples(t0_t1{1}(1),t0_t1{1},sr);` | Calls `ndi.time.fun.times2samples`, which assumes constant sampling rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.readchannels_epochsamples_ingested` | 201 | `absolute_end = ndi.time.fun.times2samples(t0_t1{1}(2),t0_t1{1},sr);` | Calls `ndi.time.fun.times2samples`, which assumes constant sampling rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.readevents_epochsamples` | 350 | `s0d = 1+round(srd*t0);` | Calculates sample index linearly from time, assuming constant rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.readevents_epochsamples` | 351 | `s1d = 1+round(srd*t1);` | Calculates sample index linearly from time, assuming constant rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.readevents_epochsamples_ingested` | 432 | `s0d = 1+round(srd*t0);` | Calculates sample index linearly from time, assuming constant rate. | Yes | Yes |
| `ndi.daq.reader.mfdaq.readevents_epochsamples_ingested` | 433 | `s1d = 1+round(srd*t1);` | Calculates sample index linearly from time, assuming constant rate. | Yes | Yes |
| `ndi.daq.system.mfdaq.readchannels` | 230 | `s0 = 1+round(sr*t0);` | Calculates sample index from time using a constant sampling rate. | Yes | Yes |
| `ndi.daq.system.mfdaq.readchannels` | 231 | `s1 = 1+round(sr*t1);` | Calculates sample index from time using a constant sampling rate. | Yes | Yes |
| `ndi.element.timeseries.samplerate` | 126 | `sr = 1/median(diff(t));` | Estimates a single constant sampling rate from the median of time differences. | No | N/A |
| `ndi.probe.timeseries.mfdaq.readtimeseriesepoch` | 81 | `s0 = 1+round(sr*t0);` | Calculates sample index from time using a constant sampling rate. | Yes | Yes |
| `ndi.probe.timeseries.mfdaq.readtimeseriesepoch` | 82 | `s1 = 1+round(sr*t1);` | Calculates sample index from time using a constant sampling rate. | Yes | Yes |
| `ndi.time.fun.samples2times` | 15 | `t = (s-1)/sr + t0_t1(1);` | Converts sample index to time using a linear formula, assuming constant rate. | No | N/A |
| `ndi.time.fun.times2samples` | 12 | `s = 1 + round( (t-t0_t1(1))*sr);` | Converts time to sample index using a linear formula, assuming constant rate. | No | N/A |
| `ndi.time.timeseries.samples2times` | 91 | `times = et.t0_t1{1}(1) + (samples-1)/sr;` | Converts sample index to time using a linear formula, assuming constant rate. | No | N/A |
| `ndi.time.timeseries.times2samples` | 67 | `samples = 1 + round ((times-et.t0_t1{1}(1))*sr);` | Converts time to sample index using a linear formula, assuming constant rate. | No | N/A |
