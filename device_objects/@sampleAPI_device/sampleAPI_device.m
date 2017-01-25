function d = sampleAPI_device(name,thedatatree,reference)
% SAMPLEAPI_DEVICE - Create a new SAMPLEAPI_DEVICE object
%
%  D = SAMPLEAPI_DEVICE(NAME, THEDATATREE)
%
%  Creates a new SAMPLEAPI_DEVICE object with the name NAME.
%  This is an abstract class that is overridden by specific devices.
%  
%  assume the synced information also contains the timeshift information
%

if nargin==1,
	error(['Not enough input arguments.]);
if nargin==2,
	sampleAPI_device_struct = struct('name',name,'datatree',thedatatree,reference','time'); 
	d = class(sampleAPI_device_struct, 'sampleAPI_device');
elseif nargin==3,
	sampleAPI_device_struct = struct('name',name,'datatree',thedatatree,'reference',reference); 
	d = class(sampleAPI_device_struct, 'sampleAPI_device');
else,
	error(['Too many input arguments.]);
end;
