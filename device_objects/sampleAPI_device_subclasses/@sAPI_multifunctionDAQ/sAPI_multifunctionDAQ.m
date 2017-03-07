% SAPI_MULTIFUNCTIONDAQ - Create a new SAPI_MULTIFUNCTIONDAQ object
%
%  D = SAPI_MULTIFUNCTIONDAQ(NAME, THEDATATREE, EXP)
%
%  Creates a new SAPI_MULTIFUNCTIONDAQ object with NAME, DATATREE and associated EXP.
%  This is an abstract class that is overridden by specific devices.
%

% function d = sAPI_multifunctionDAQ(name, thedatatree, exp)
% sAPI_multifunctionDAQ_struct = struct('exp',exp);
% d = class(sAPI_multifunctionDAQ_struct, 'sAPI_multifunctionDAQ',sampleAPI_device(name,thedatatree));

classdef sAPI_multifunctionDAQ < handle & sampleAPI_device
   properties
      exp,
   end
   methods
      function obj = sAPI_multifunctionDAQ_cons(obj,exp,name,thedatatree,reference)
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

      function channels = getchannels(self)
        channels = struct('name',[],'type',[]);
        channels = channels([]);
      end

   end
end
