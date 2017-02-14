classdef sampleAPI_device_handle < handle
   properties
      name,
      datatree,
      reference,
   end
   methods
      function obj = sampleAPI_device_handle(name,thedatatree,reference)
         if nargin==1,
            error(['Not enough input arguments.']);
        elseif nargin==2,
            obj.name = name;
            obj.datatree = thedatatree;
            obj.reference = 'time';
        elseif nargin==3,
            obj.name = name;
            obj.datatree = thedatatree;
            obj.reference = reference;
        else,
            error(['Too many input arguments.']);
        end;
      end
   end
end