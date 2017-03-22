function [S] = device_add(S, dev)
%DEVICE_ADD - Add a sampling device to a NSD
%  
% S = DEVICE_ADD(S, DEV) adds the device DEV to the NSD S
% 

if ~isa(dev,'NSD_device'), error(['dev is not a NSD_device']); end;

if isempty(S.devices),
    S.devices = dev;
else,
    S.devices(end+1) = dev;
end;
