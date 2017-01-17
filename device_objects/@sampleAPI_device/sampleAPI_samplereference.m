function [ reference ] = sampleAPI_samplereference( sAPI, type )
%SAMPLEAPI_SAMPLEREFERENCE set the type of time reference for each sample
%   reference can be in units of "time" of "samples"

sAPI.referenece = type;
reference = type;
end

