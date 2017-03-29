function d = sAPI_stimtimes_example(name)
% SAPI_STIMTIMES_EXAMPLE - Create an sAPI_stimtimes_example object 
%
%  D = SAPI_STIMTIMES_EXAMPLE(NAME)
%
%  Creates a new SAMPLEAPI_DEVICE object with the name NAME.
%  This object has a single interval of recording of stimulus timing information.
%

d = class(struct([]),'sAPI_stimtimes_example',sampleAPI_device(name));
