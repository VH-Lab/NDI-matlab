function d = NSD_stimtimes_example(name)
% SAPI_STIMTIMES_EXAMPLE - Create an NSD_stimtimes_example object 
%
%  D = SAPI_STIMTIMES_EXAMPLE(NAME)
%
%  Creates a new NSD_DEVICE object with the name NAME.
%  This object has a single interval of recording of stimulus timing information.
%

d = class(struct([]),'NSD_stimtimes_example',NSD_device(name));
