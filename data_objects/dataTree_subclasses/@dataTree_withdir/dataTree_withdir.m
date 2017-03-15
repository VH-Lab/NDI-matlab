% DATATREE_WITHDIR - Create a new DATATREE_FLAT object
%
%  DT = DATATREE_WITHDIR(EXP)   
%
%  Creates a new data tree object with the experiments 
%  This class in inhereted from datatree and with directory organization
%


classdef dataTree_withdir < handle & dataTree
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

% function dt = dataTree_withdir(exp, filetype)

% s = struct('filetype',filetype);
% 
% dt = class(s,'dataTree_flat',dataTree(exp));
