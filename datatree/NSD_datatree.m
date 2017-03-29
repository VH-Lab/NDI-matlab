% NSD_DATATREE - Create a new NSD_DATATREE abstract object
%
%  DT = DATATREE(EXP)   
%
%  Creates a new DATATREE object with the experiment name.
%  This is an abstract class that is overridden by specific type of format of data.
%

classdef NSD_datatree < handle
	properties
		exp;
		fileparameters;
	end

	methods
	        function obj = NSD_datatree(exp_, fileparameters_)
		% NSD_DATATREE - Create a new NSD_DATATREE object that is associated with an experiment and device
		%
		%   OBJ = NSD_DATATREE(EXP, [ FILEPARAMETERS])
		%
		% Creates a new NSD_DATATREE object that negotiates the data tree of device's data that is
		% stored in an experiment EXP.
		%
		% Inputs: EXP - an NSD_EXPERIMENT ; DEVICE - an NSD_DEVICE object
		% Optional input: FILEPARAMETERS - the files that are recorded in each epoch of DEVICE in this
		%               data tree style
		% Output: OBJ - an NSD_DATATREE object
		%
		% See also: NSD_EXPERIMENT, NSD_DEVICE
		%

			if ~isa(exp_,'NSD'),
				error(['exp must be an experiment of type NSD']);
			end;
			obj.exp = exp_;
				
			if nargin > 1,
				obj.fileparameters = fileparameters_;
			else,
				obj.fileparameters = [];
			end;
		end;
        
		function fullpathfilename = getepochfilelocation(self, N)
		% GETEPOCHFILELOCATION - Return the epoch file location for a given device and data tree
		%  
		%  FULLPATHFILENAME = GETEPOCHFILELOCATION(SELF, N)
		%
		% Inputs:
		%     SELF - the data tree object
		%     N - the epoch number
		% 
		% Output: 
		%     FULLPATHFILENAME - The full pathname of the epoch record file
		%
		%
			exp_path = getpath(self.exp);
				% now return path of epoch record file
			fullpathfilename = exp_path;
		end

		function setfileparameters(self, thefileparameters)
		% SETFILEPARAMETERS - Set the fileparameters field of a NSD_DATATREE object
		%
		%  SELF = SETFILEPARAMETERS(SELF, THEFILEPARAMETERS)
		%
		%  (Need to better describe)
		%
		%  The FILEPARAMETERS should be a structure with the following fields:
		%  Fieldname:              | Description
		%  ----------------------------------------------------------------------
		%  filematch               | A string or cell list of strings that need to be matched
		%                          | Wild cards are allowed.
		%                          |   Example: filematch = '*.rhd'
		%                          |   Example: filematch = {'*.rhd', 'stimtimes*.txt'}
		%                          |   Example: filematch = {'#.rhd',  'stimtimes#.txt'} (# is the same, unknown string)
		%
		% 

	end % methods

end % classdef

