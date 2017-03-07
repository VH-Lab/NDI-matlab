% SAPI_IMAGE - Create a new SAPI_IMAGE class handle object
%
%  D = SAPI_IMAGE(NAME, THEDATATREE,EXP)
%
%  Creates a new SAPI_IMAGE object with NAME, THEDATATREE and associated EXP.
%  This is an abstract class that is overridden by specific devices.
%

% sAPI_image_struct = struct('exp',exp);
% d = class(sAPI_image_struct, 'sAPI_image',sampleAPI_device(name,thedatatree,reference));


classdef sAPI_image < handle & sampleAPI_device
   properties
       exp,
   end
   methods
      function obj = sAPI_image_cons(obj,exp,name,thedatatree,reference)
        if nargin==1 || nargin ==2 || nargin ==3,
            error(['Not enough input arguments.']);
        elseif nargin==4,
            obj.exp = exp;
            obj.name = name;
            obj.datatree = thedatatree;
            obj.reference = 'time';
        elseif nargin==5,
            obj.exp = exp;
            obj.name = name;
            obj.datatree = thedatatree;
            obj.reference = reference;
        else,
            error(['Too many input arguments.']);
        end;
      end
   end
end
