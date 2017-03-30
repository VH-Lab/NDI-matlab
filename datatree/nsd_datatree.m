% NSD_DATATREE - Create a new NSD_DATATREE abstract object
%
%  DT = NSD_DATATREE(EXP)   
%
%  The NSD_DATATREE object class
%
%    MORE DOCS here
%

classdef nsd_datatree < handle
	properties (SetAccess=protected)
		exp;
		fileparameters;
	end
	properties (Access=private) % potential private variables
	end

	methods
	        function obj = nsd_datatree(exp_, fileparameters_)
		% NSD_DATATREE - Create a new NSD_DATATREE object that is associated with an experiment and device
		%
		%   OBJ = NSD_DATATREE(EXP, [ FILEPARAMETERS])
		%
		% Creates a new NSD_DATATREE object that negotiates the data tree of device's data that is
		% stored in an experiment EXP.
		%
		% Inputs: EXP - an NSD_EXPERIMENT ; DEVICE - an NSD_DEVICE object
		% Optional input: FILEPARAMETERS - the files that are recorded in each epoch of DEVICE in this
		%               data tree style (see NSD_DATATREE/SETFILEPARAMETERS for description)
		% Output: OBJ - an NSD_DATATREE object
		%
		% See also: NSD_EXPERIMENT, NSD_DEVICE
		%

			if ~isa(exp_,'nsd_experiment'),
				error(['exp must be an experiment of type nsd_experiment']);
			end;
			obj.exp = exp_;
				
			if nargin > 1,
				obj = setfileparameters(obj,fileparameters_);
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
		end;

		function fullpathfilenames = getepochfiles(self, N)
		% GETEPOCHFILES - Return the file paths for one recording epoch
		%
		%  FULLPATHFILENAMES = GETEPOCHFILES(SELF, N)
		%
		%  Return the file names or file paths associated with one recording epoch.
		%
		%  Uses the FILEPARAMETERS (see NSD_DATATREE/SETFILEPARAMETERS) to identify recording
		%  epochs under the EXPERIMENT path.
		%
			% developer note: possibility of caching this with some timeout

			exp_path = getpath(self.exp);
			all_epochs = findfilegroups(exp_path, self.fileparameters.filematch);
			if length(all_epochs)>=N,
				fullpathfilenames = all_epochs{N};
			else,
				error(['No epoch number ' int2str(N) ' found.']);
			end;
		end;

		function N = numepochs(self)
		% NUMEPOCHS - Return the number of epochs in an NSD_DATATREE
		%
		%   N = NUMEPOCHS(SELF)
		%
		% Returns the number of available epochs in the data tree SELF.
		%
		% See also: NSD_DATATREE/GETEPOCHFILES

			% developer note: possibility of caching this with some timeout

			exp_path = getpath(self.exp);
			all_epochs = findfilegroups(exp_path, self.fileparameters.filematch);
			N = numel(all_epochs);
		end;

		function self = setfileparameters(self, thefileparameters)
		% SETFILEPARAMETERS - Set the fileparameters field of a NSD_DATATREE object
		%
		%  SELF = SETFILEPARAMETERS(SELF, THEFILEPARAMETERS)
		%
		%  THEFILEPARAMETERS is a string or cell list of strings that specifies the files
		%  that comprise an epoch. 
		%
		%         Example: filematch = '.*\.ext\>'
		%         Example: filematch = {'myfile1.ext1', 'myfile2.ext2'}
		%         Example: filematch = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
		%
		%
		%  Alternatively, THEFILEPARAMETERS can be delivered as a structure with the following fields:
		%  Fieldname:              | Description
		%  ----------------------------------------------------------------------
		%  filematch               | A string or cell list of strings that need to be matched
		%                          | Regular expressions are allowed
		%                          |   Example: filematch = '.*\.ext\>'
		%                          |   Example: filematch = {'myfile1.ext1', 'myfile2.ext2'}
		%                          |   Example: filematch = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
		%
		% 
			if isa(thefileparameters,'char'),
				thefileparameters = {thefileparameters};
			end;
			if isa(thefileparameters,'cell'),
				thefileparameters = struct('filematch',{thefileparameters});
			end;
			self.fileparameters = thefileparameters;
		end;
	end % methods

end % classdef

