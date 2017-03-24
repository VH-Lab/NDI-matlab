function d = NSD_ephys_example(name)
% SAPI_EPHYS_EXAMPLE - Create an NSD_ephys_example object 
%
%  D = SAPI_EPHYS_EXAMPLE(NAME)
%
%  Creates a new NSD_DEVICE object with the name NAME.
%  This object has a single interval of recording of action potentials.
%

d = class(struct([]),'NSD_ephys_example',NSD_device(name));
