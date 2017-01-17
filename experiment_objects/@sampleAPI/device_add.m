function [S] = device_add(S, dev)
%DEVICE_ADD - Add a sampling device to a SAMPLEAPI
%  
% S = DEVICE_ADD(S, DEV) adds the device DEV to the SAMPLEAPI S
% 

if ~isa(dev,'sampleAPI_device'), error(['dev is not a sampleAPI_device']); end;

if isempty(S.devices),
    S.devices = dev;
else,
    S.devices(end+1) = dev;
end;
