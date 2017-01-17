function d = sampleAPI_device(name,reference)
% SAMPLEAPI_DEVICE - Create a new SAMPLEAPI_DEVICE object
%
%  D = SAMPLEAPI_DEVICE(NAME)
%
%  Creates a new SAMPLEAPI_DEVICE object with the name NAME.
%  This is an abstract class that is overridden by specific devices.
%  
%  assume the synced information also contains the timeshift information
%
if nargin==1,
    sampleAPI_device_struct = struct('name',name,'reference','time'); 
    d = class(sampleAPI_device_struct, 'sampleAPI_device');
elseif nargin==2,
    sampleAPI_device_struct = struct('name',name,'reference',reference); 
    d = class(sampleAPI_device_struct, 'sampleAPI_device');
