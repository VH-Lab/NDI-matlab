# pyraview

The `pyraview` document class stores information about multi-resolution data structures (pyramids).

It inherits from `epochclocktimes` and `filter`.

## Fields

### label

A string label.

### nativeRate

Native sampling rate.

### nativeStartTime

Native t0.

### channels

Number of channels in the probe.

### dataType

The data type of the stored values. Can be one of:
* 'int8'
* 'uint8'
* 'int16'
* 'uint16'
* 'int32'
* 'uint32'
* 'int64'
* 'uint64'
* 'single'
* 'double'

### decimationLevels

Vector of levels (integers).

### decimationSamplingRates

Vector of rates (doubles).

### decimationStartTimes

Vector of decimation start times (doubles).

## Dependencies

* **element_id**: The ID of the element this pyraview is associated with.

## Files

* **level1.bin**
* **level2.bin**
* ...
* **level10.bin**
