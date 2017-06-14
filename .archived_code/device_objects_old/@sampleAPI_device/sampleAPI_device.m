function d = NSD_device(name,thefiletree,reference)
% NSD_DEVICE - Create a new NSD_DEVICE object
%
%  D = NSD_DEVICE(NAME, THEFILETREE,REFERENCE)
%
%  Creates a new NSD_DEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.
%  
%

if nargin==1,
	error(['Not enough input arguments.']);
elseif nargin==2,
	NSD_device_struct = struct('name',name,'filetree',thefiletree,reference','time'); 
	d = SimpleHandleClass(NSD_device_struct, 'NSD_device');
elseif nargin==3,
	NSD_device_struct = struct('name',name,'filetree',thefiletree,'reference',reference); 
	d = SimpleHandleClass(NSD_device_struct, 'NSD_device');
else,
	error(['Too many input arguments.']);
end;
