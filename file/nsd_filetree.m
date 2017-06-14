% NSD_FILETREE - object class for accessing files on disk
%
%  DT = NSD_FILETREE(EXP)   
%
%  The NSD_FILETREE object class
%
%    See NSD_FILETREE/NSD_FILETREE
%

classdef nsd_filetree < handle
	properties (SetAccess=protected)
		exp;
		fileparameters;
		epochrecord_class;
		epochrecord_fileparameters;
	end
	properties (Access=private) % potential private variables
	end

	methods
	        function obj = nsd_filetree(exp_, fileparameters_, epochrecord_class_, epochrecord_fileparameters_)
		% NSD_FILETREE - Create a new NSD_FILETREE object that is associated with an experiment and device
		%
		%   OBJ = NSD_FILETREE(EXP, [ FILEPARAMETERS, EPOCHRECORD_CLASS, EPOCHRECORD_FILEPARAMETERS])
		%
		% Creates a new NSD_FILETREE object that negotiates the data tree of device's data that is
		% stored in an experiment EXP.
		%
		% Inputs:
		%      EXP: an NSD_EXPERIMENT ; DEVICE - an NSD_DEVICE object
		% Optional inputs:
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see NSD_FILETREE/SETFILEPARAMETERS for description)
		%      EPOCHRECORD_CLASS: the class of epoch_record to be used; 'nsd_epochrecord' is used by default
		%      EPOCHRECORD_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see NSD_FILETREE/SETEPOCHRECORDFILEPARAMETERS). By default, the file location
		%          [EXP]/.nsd/device_name/epoch_NNNNNNNNN.nsderf is used.
		% 
		% Output: OBJ - an NSD_FILETREE object
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

			if nargin > 2,
				obj.epochrecord_class = epochrecord_class_;
			else,
				obj.epochrecord_class = 'nsd_epochrecord';
			end;

			if nargin > 3,
				obj = setepochfileparameters(obj,epochrecord_fileparameters_);
			else,
				obj.epochrecord_fileparameters = [];
			end;
		end;
        
		function epochrecord = getepochrecord(self, N, devicename)
		% GETEPOCHRECORD - Return the epoch record for a given nsd_filetree and epoch number
		%  
		%  EPOCHRECORD = GETEPOCHRECORD(SELF, N, DEVICENAME)
		%
		% Inputs:
		%     SELF - the data tree object
		%     N - the epoch number
		%     DEVICENAME - The NSD name of the device
		% 
		% Output: 
		%     EPOCHRECORD - The epoch record information associated with epoch N for device with name DEVICENAME
		%
		%
			% need to get the epoch file
			% epoch file must either be in a default location or it must be among the epoch files

			% default
			epochrecordfile_fullpath = [getpath(self.exp) filesep '.nsd' filesep devicename filesep 'epoch_' int2str(N) '.nsderf'];

			if ~isempty(self.epochrecord_fileparameters),
				epochfiles = getepochfiles(self,N);
				fn = {};
				for i=1:length(epochfiles),
					[pa,name,ext] = fileparts(epochfiles{i});
					fn{i} = [name ext];
				end;
				tf = strcmp_substitution(epochrecord_fileparameters, fn);
				indexes = find(tf);
				if numel(indexes)>0,
					epochrecordfile_fullpath = epochfiles{indexes(1)};
				end;
			end;
			
			eval(['epochrecord = ' self.epochrecord_class '(epochrecordfile_fullpath);']);
		end;

		function fullpathfilenames = getepochfiles(self, N)
		% GETEPOCHFILES - Return the file paths for one recording epoch
		%
		%  FULLPATHFILENAMES = GETEPOCHFILES(SELF, N)
		%
		%  Return the file names or file paths associated with one recording epoch.
		%
		%  Uses the FILEPARAMETERS (see NSD_FILETREE/SETFILEPARAMETERS) to identify recording
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
		% NUMEPOCHS - Return the number of epochs in an NSD_FILETREE
		%
		%   N = NUMEPOCHS(SELF)
		%
		% Returns the number of available epochs in the data tree SELF.
		%
		% See also: NSD_FILETREE/GETEPOCHFILES

			% developer note: possibility of caching this with some timeout

			exp_path = getpath(self.exp);
			all_epochs = findfilegroups(exp_path, self.fileparameters.filematch);
			N = numel(all_epochs);
		end;

		function self = setfileparameters(self, thefileparameters)
		% SETFILEPARAMETERS - Set the fileparameters field of a NSD_FILETREE object
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

		function self = setepochrecordparameters(self, theepochrecordfileparameters)
		% SETEPOCHRECORDFILEPARAMETERS - Set the epoch record fileparameters field of a NSD_FILETREE object
		%
		%  SELF = SETEPOCHRECORDFILEPARAMETERS(SELF, THEEPOCHRECORDFILEPARAMETERS)
		%
		%  THEEPOCHRECORDFILEPARAMETERS is a string or cell list of strings that specifies the epoch record
		%  file. By default, if no parameters are specified, the epoch record file is located at:
		%   [EXP]/.nsd/device_name/epoch_NNNNNNNNN.nsderf, where [EXP] is the experiment's path.
		%
		%  However, one can pass search parameters that will search among all the file names returned by
		%  NSD_FILETREE/GETEPOCHS. The search parameter should be a regular expression or a set of regular
		%  expressions such as:
		%
		%         Example: theepochrecordfileparameters = '.*\.ext\>'
		%         Example: theepochrecordfileparameters = {'myfile1.ext1', 'myfile2.ext2'}
		%         Example: theepochrecordfileparameters = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
		%
			if isa(theepochrecordfileparameters,'char'),
				theepochrecordfileparameters = {thefileparameters};
			end;
			self.epochrecord_fileparameters = theepochrecordfileparameters;
		end;
	end % methods

end % classdef

