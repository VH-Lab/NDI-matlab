# CLASS ndi.time.timemapping

```
  NDI.TIME.TIMEMAPPING - class for managing mapping of time across epochs and devices
 
  Describes mapping from one time base to another. The base class, ndi.time.timemapping, provides
  polynomial mapping, although usually only linear mapping is used.
  The property MAPPING is a vector of length N+1 that describes the coefficients of a
  polynomial such that:
 
  t_out = mapping(1)*t_in^N + mapping(2)*t_in^(N-1) + ... mapping(N)*t_in + mapping(N+1)
 
  Usually, one specifies a linear relationship only, with MAPPING = [scale shift] so that
 
  t_out = scale * t_in + shift


```
## Superclasses
*none*

## Properties

| Property | Description |
| --- | --- |
| *mapping* | mapping parameters; in the ndi.time.timemapping base class, this is a polynomial (see help POLYVAL) |


## Methods 

| Method | Description |
| --- | --- |
| *map* | perform a mapping from one time base to another |
| *timemapping* | ndi.time.timemapping |


### Methods help 

**map** - *perform a mapping from one time base to another*

```
T_OUT = MAP(NDI_TIMEMAPPING_OBJ, T_IN)
 
  Perform the mapping described by NDI_TIMEMAPPING_OBJ from one time base to another.
 
  In the base class ndi.time.timemapping, the mapping is a polynomial.
```

---

**timemapping** - *ndi.time.timemapping*

```
NDI_TIMEMAPPING_OBJ = ndi.time.timemapping()
     or
  NDI_TIMEMAPPING_OBJ = ndi.time.timemapping(MAPPING)
 
  Creates a new ndi.time.timemapping object. In this base class,
  the ndi.time.timemapping object specifies a polynomial mapping
  from one time base to another.
  
  If the function is called with no input arguments, then
  the trivial mapping MAPPING = [ 1 0 ] is used; this corresponds
  to the polynomial t_out = 1*t_in + 0.
 
  Typically, the mapping is linear, so that MAPPING = [scale shift].
 
  See also: POLYVAL

    Documentation for ndi.time.timemapping/timemapping
       doc ndi.time.timemapping
```

---

