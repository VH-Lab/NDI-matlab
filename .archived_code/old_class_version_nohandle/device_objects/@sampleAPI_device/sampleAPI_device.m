function d = sampleAPI_device(name,thefiletree,reference)
% SAMPLEAPI_DEVICE - Create a new SAMPLEAPI_DEVICE object
%
%  D = SAMPLEAPI_DEVICE(NAME, THEFILETREE,REFERENCE)
%
%  Creates a new SAMPLEAPI_DEVICE object with name and specific data tree object.
%  This is an abstract class that is overridden by specific devices.
%  
%

if nargin==1,
	error(['Not enough input arguments.']);
elseif nargin==2,
	sampleAPI_device_struct = struct('name',name,'filetree',thefiletree,reference','time'); 
	d = SimpleHandleClass(sampleAPI_device_struct, 'sampleAPI_device');
elseif nargin==3,
	sampleAPI_device_struct = struct('name',name,'filetree',thefiletree,'reference',reference); 
	d = SimpleHandleClass(sampleAPI_device_struct, 'sampleAPI_device');
else,
	error(['Too many input arguments.']);
end;


% classdef sampleAPI_device < handle
%    properties
%       name,
%       filetree,
%       reference,
%    end
%    methods
%       function obj = sampleAPI_device_handle(name,thefiletree,reference)
%          if nargin==1,
%             error(['Not enough input arguments.']);
%         elseif nargin==2,
%             obj.name = name;
%             obj.filetree = thefiletree;
%             obj.reference = 'time';
%         elseif nargin==3,
%             obj.name = name;
%             obj.filetree = thefiletree;
%             obj.reference = reference;
%         else,
%             error(['Too many input arguments.']);
%         end;
%       end
%    end
% end

end

