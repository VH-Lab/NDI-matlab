function d = sAPI_ephys_example(name)
% SAPI_EPHYS_EXAMPLE - Create an sAPI_ephys_example object 
%
%  D = SAPI_EPHYS_EXAMPLE(NAME)
%
%  Creates a new SAMPLEAPI_DEVICE object with the name NAME.
%  This object has a single interval of recording of action potentials.
%

d = class(struct([]),'sAPI_ephys_example',sampleAPI_device(name));
