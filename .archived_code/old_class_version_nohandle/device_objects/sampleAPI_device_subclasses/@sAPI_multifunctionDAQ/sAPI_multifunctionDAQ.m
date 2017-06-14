<<<<<<< HEAD:device_objects/sampleAPI_device_subclasses/@sAPI_multifunctionDAQ/sAPI_multifunctionDAQ.m
=======
function d = sAPI_multifunctionDAQ(name, thefiletree, exp)
>>>>>>> 94360047df90390c706266a3ab801ce24431d8b6:.archived_code/old_class_version_nohandle/device_objects/sampleAPI_device_subclasses/@sAPI_multifunctionDAQ/sAPI_multifunctionDAQ.m
% SAPI_MULTIFUNCTIONDAQ - Create a new SAPI_MULTIFUNCTIONDAQ object
%
%  D = SAPI_MULTIFUNCTIONDAQ(NAME, THEFILETREE, EXP)
%
%  Creates a new SAPI_MULTIFUNCTIONDAQ object with NAME, FILETREE and associated EXP.
%  This is an abstract class that is overridden by specific devices.
<<<<<<< HEAD:device_objects/sampleAPI_device_subclasses/@sAPI_multifunctionDAQ/sAPI_multifunctionDAQ.m
%

% function d = sAPI_multifunctionDAQ(name, thefiletree, exp)
% sAPI_multifunctionDAQ_struct = struct('exp',exp);
% d = class(sAPI_multifunctionDAQ_struct, 'sAPI_multifunctionDAQ',sampleAPI_device(name,thefiletree));
=======
%  
>>>>>>> 94360047df90390c706266a3ab801ce24431d8b6:.archived_code/old_class_version_nohandle/device_objects/sampleAPI_device_subclasses/@sAPI_multifunctionDAQ/sAPI_multifunctionDAQ.m

classdef sAPI_multifunctionDAQ < handle & sampleAPI_device
   properties
      exp,
   end
   methods
      function obj = sAPI_multifunctionDAQ_cons(obj,exp,name,thefiletree,reference)
        if nargin==1 || nargin ==2 || nargin ==3,
            error(['Not enough input arguments.']);
        elseif nargin==4,
            obj.exp = exp;
            obj.name = name;
            obj.filetree = thefiletree;
            obj.reference = 'time';
        elseif nargin==5,
            obj.exp = exp;
            obj.name = name;
            obj.filetree = thefiletree;
            obj.reference = reference;
        else,
            error(['Too many input arguments.']);
        end;
      end

      function channels = getchannels(self)
        channels = struct('name',[],'type',[]);
        channels = channels([]);
      end

<<<<<<< HEAD:device_objects/sampleAPI_device_subclasses/@sAPI_multifunctionDAQ/sAPI_multifunctionDAQ.m
   end
end
=======
d = class(sAPI_multifunctionDAQ_struct, 'sAPI_multifunctionDAQ',sampleAPI_device(name,thefiletree));
>>>>>>> 94360047df90390c706266a3ab801ce24431d8b6:.archived_code/old_class_version_nohandle/device_objects/sampleAPI_device_subclasses/@sAPI_multifunctionDAQ/sAPI_multifunctionDAQ.m
