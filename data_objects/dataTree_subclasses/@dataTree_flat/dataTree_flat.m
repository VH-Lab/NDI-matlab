% DATATREE_FLAT - Create a new DATATREE_FLAT object
%
%  DT = DATATREE_FLAT(EXP, FILETYPE)   
%
%  Creates a new data tree object with the experiment name 
%  This class in inhereted from datatree and with flat organization
%


classdef dataTree_flat < handle & dataTree
    properties
		exp;
		datatree;
	end
	methods
        function obj = sampleAPI_device(name,thedatatree)
			if nargin==0 || nargin==1,
				error(['Not enough input arguments.']);
			elseif nargin==2,
                obj.name = name;
                obj.datatree = thedatatree;
            else,
                error(['Too many input arguments.']);
			end;
        end
        
        function epoch = get.datatree(obj)    
        end
        
        function exp = get.exp(obj)
        end
    end
end

% function dt = dataTree_flat(exp, filetype)

% s = struct('filetype',filetype);
% 
% dt = class(s,'dataTree_flat',dataTree(exp));