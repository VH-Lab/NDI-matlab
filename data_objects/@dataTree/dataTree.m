% DATATREE - Create a new DATATREE abstract object
%
%  DT = DATATREE(EXP)   
%
%  Creates a new DATATREE object with the experiment name.
%  This is an abstract class that is overridden by specific type of format of data.
%



classdef dataTree < handle
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

	function fullpathfilename = getepochfilelocation(self, dev, N)
	% GETEPOCHFILELOCATION - Return the epoch file location for a given device and data tree
	%  
	%  FULLPATHFILENAME = GETEPOCHFILELOCATION(SELF, THE_SAMPLEAPI_DEVICE, N)
	%
	% Inputs:
	%     SELF - the data tree object
	%     THE_SAMPLEAPI_DEVICE- the device 
	%     N - the epoch number
	% 
	% Output: 
	%     FULLPATHFILENAME - The full pathname of the epoch record file
	%
	%

		exp_path = self.exp.getpath();  
			% now return path of epoch record file
    end
end

% function dt = dataTree(exp)

% 
% dataTree_struct = struct('exp',exp);
% dt = class(dataTree_struct, 'dataTree');
