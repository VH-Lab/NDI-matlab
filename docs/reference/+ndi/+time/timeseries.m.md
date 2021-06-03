# CLASS ndi.time.timeseries

```
  NDI_TIMESERIES - abstract class for managing time series data


```
## Superclasses
**[ndi.documentservice](../documentservice.m.md)**

## Properties

*none*


## Methods 

| Method | Description |
| --- | --- |
| *newdocument* | create a new ndi.document based on information in this object |
| *readtimeseries* | read a time series from this parent object (ndi.time.timeseries) |
| *samplerate* | return the sample rate of an ndi.time.timeseries object |
| *samples2times* | convert from the timeseries time to sample numbers |
| *searchquery* | create a search query to find this object as an ndi.document |
| *times2samples* | convert from the timeseries time to sample numbers |
| *timeseries* | create an ndi.time.timeseries object |


### Methods help 

**newdocument** - *create a new ndi.document based on information in this object*

```
NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_DOCUMENTSERVICE_OBJ)
 
  Create a new ndi.document based on information in this class.
 
  The base ndi.documentservice class returns empty.

Help for ndi.time.timeseries/newdocument is inherited from superclass NDI.DOCUMENTSERVICE
```

---

**readtimeseries** - *read a time series from this parent object (ndi.time.timeseries)*

```
[DATA, T, TIMEREF] = READTIMESERIES(NDI_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
 
   Reads timeseries data from an ndi.time.timeseries object. The DATA and time information T that are
   returned depend on the the specific subclass of ndi.time.timeseries that is called (see READTIMESERIESEPOCH).
 
   TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the time reference for
   T0, T1, or it can be a single number, which will indicate the data are to be read from that
   epoch.
 
   DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
   ndi.time.timereference object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.
```

---

**samplerate** - *return the sample rate of an ndi.time.timeseries object*

```
SR = SAMPLE_RATE(NDI_TIMESERIES_OBJ, EPOCH)
 
  Returns the sampling rate of a given ndi.time.timeseries object for the epoch
  EPOCH. EPOCH can be specified as an index or EPOCH_ID.
 
  If NDI_TIMESERIES_OBJ is not regularly sampled, then -1 is returned.
```

---

**samples2times** - *convert from the timeseries time to sample numbers*

```
SAMPLES = TIME2SAMPLES(NDI_TIMESERIES_OBJ, EPOCH, TIMES)
 
  For a given ndi.time.timeseries object and a recording epoch EPOCH,
  return the sample index numbers SAMPLE that corresponds to the times TIMES.
  The first sample in the epoch is 1.
  The TIMES requested might be out of bounds of the EPOCH; no checking is performed.
  
  TODO: convert times to dev_local_clock
```

---

**searchquery** - *create a search query to find this object as an ndi.document*

```
SQ = SEARCHQUERY(NDI_DOCUMENTSERVICE_OBJ)
 
  Return a search query that can be used to find this object's representation as an
  ndi.document.
 
  The base class ndi.documentservice just returns empty.

Help for ndi.time.timeseries/searchquery is inherited from superclass NDI.DOCUMENTSERVICE
```

---

**times2samples** - *convert from the timeseries time to sample numbers*

```
SAMPLES = TIMES2SAMPLES(NDI_TIMESERIES_OBJ, EPOCH, TIMES)
 
  For a given ndi.time.timeseries object and a recording epoch EPOCH,
  return the sample index numbers SAMPLE that corresponds to the times TIMES.
  The first sample in the epoch is 1.
  The TIMES requested might be out of bounds of the EPOCH; no checking is performed.
```

---

**timeseries** - *create an ndi.time.timeseries object*

```
NDI_TIMESERIES_OBJ = ndi.time.timeseries()
 
  This function creates an ndi.time.timeseries object, which is an
  abstract class that defines methods for other objects that deal with
  time series.
```

---

