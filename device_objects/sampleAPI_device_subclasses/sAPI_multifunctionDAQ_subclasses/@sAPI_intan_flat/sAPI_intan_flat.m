% SAPI_INTAN_FLAT - Create a new SAPI_INTAN_FLAT object
%
%  D = SAPI_INTAN_FLAT(NAME,THEDATATREE, EXP)
%
%  Creates a new SAPI_INTAN_FLAT object with NAME, THEDATATREE and
%  associated EXP
%

classdef sAPI_intan_flat < handle
   properties
      exp,
      name,
      datatree,
      reference,
   end
   methods
      function obj = sAPI_intan_flat(exp,name,thedatatree,reference)
         if nargin==1,
            error(['Not enough input arguments.']);
        elseif nargin==3,
            obj.exp = exp;
            obj.name = name;
            obj.datatree = thedatatree;
            obj.reference = 'time';
        elseif nargin==4,
            obj.exp = exp;
            obj.name = name;
            obj.datatree = thedatatree;
            obj.reference = reference;
        else,
            error(['Too many input arguments.']);
        end;
      end

      function channels = getchannels()
      end

      function intervals = getintervals()
      end

      function channels_data = read_channel()
      end

   end
end
