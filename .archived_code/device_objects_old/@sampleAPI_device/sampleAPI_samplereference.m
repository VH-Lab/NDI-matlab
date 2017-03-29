function [ reference ] = NSD_samplereference( NSD, type )
%NSD_SAMPLEREFERENCE set the type of time reference for each sample
%   reference can be in units of "time" of "samples"

NSD.referenece = type;
reference = type;
end

