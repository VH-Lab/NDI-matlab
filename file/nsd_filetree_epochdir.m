% NSD_FILETREE_EPOCHDIR - Create a new NSD_FILETREE_EPOCHDIR object
%
%  DT = FILETREE_EPOCHDIR(EXP, FILETYPE)   
%
%  Creates a new file tree object with the experiment name 
%  This class in inhereted from filetree and with epochdir organization
%

classdef nsd_filetree_epochdir < nsd_filetree
	properties
	end

	methods

		function obj = nsd_filetree_epochdir(varargin)
		% NSD_FILETREE_EPOCHDIR - Create a new NSD_FILETREE_EPOCHDIR object that is associated with an experiment and device
		%
		%   OBJ = NSD_FILETREE_EPOCHDIR(EXP, [FILEPARAMETERS, EPOCHCONTENTS_CLASS, EPOCHCONTENTS_FILEPARAMETERS])
		%
		% Creates a new NSD_FILETREE_EPOCHDIR object that negotiates the data tree of device's data that is
		% stored in an experiment EXP.
		%
		% (document FILEPARAMETERS)
		%
		% Inputs: EXP - an NSD_EXPERIMENT ; FILEPARAMETERS - the files that are recorded in each epoch
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see NSD_FILETREE/SETFILEPARAMETERS for description)
		%      EPOCHCONTENTS_CLASS: the class of epoch_record to be used; 'nsd_epochcontents' is used by default
		%      EPOCHCONTENTS_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see NSD_FILETREE/SETEPOCHCONTENTSFILEPARAMETERS). By default, the file location
		%          specified in NSD_FILETREE/EPOCHCONTENTSFILENAME is used
		%
		% Output: OBJ - an NSD_FILETREE_EPOCHDIR object
		%
		% See also: NSD_EXPERIMENT, NSD_IODEVICE
		%
			obj = obj@nsd_filetree(varargin{:});
		end

		% in NSD_BASE, need to change epochcontentsfilename to defaultepochcontentsfilename

		%% methods overriding NSD_BASE

			function [obj,properties_set] = setproperties(nsd_filetree_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_FILETREE object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_FILETREE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_FILETREE_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_FILETREE_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NSD_FILETREE that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NSD_FILETREE).
			%
				fn = fieldnames(nsd_filetree_obj);
				obj = nsd_filetree_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						else,
							switch properties{i}(2:end),
								case 'fileparameters',
									if ~isempty(values{i}),
										fp = eval(values{i});
										obj = obj.setfileparameters(fp);
									else,
										obj.fileparameters = [];
									end;
								case 'epochcontents_fileparameters',
									if ~isempty(values{i}),
										fp = eval(values{i});
										obj = obj.setepochcontentsfileparameters(fp);
									else,
										obj.epochcontents_fileparameters = [];
									end
							otherwise,
								error(['Do not know how to set property ' properties{i}(2:end) '.']);
							end
							properties_set{end+1} = properties{i}(2:end);
						end
					end
				end
		end % setproperties()

		%% methods overriding NSD_EPOCHSET

		function id = epochid(self, epoch_number, epochfiles)
		% EPOCHID = Get the epoch identifier for a particular epoch
		%
		% ID = EPOCHID(SELF, EPOCH_NUMBER, [EPOCHFILES])
		%
		% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
		% For the NSD_FILETREE_EPOCHDIR object, each EPOCH is organized in its own subdirectory,
		% and the epoch identifier is the _name_ of the subdirectory.
		%
		% For example, if my device has a file tree that reads files with extension .dat,
		% the experiment directory is
		%
		% myexperiment/
		%       t00001/
		%          mydata.dat
		%
		% Then ID is 't00001'
		%
			if nargin < 3,
				epochfiles = getepochfiles(self, epoch_number);
			end
			[pathdir,filename] = fileparts(epochfiles{1});
			[abovepath, id] = fileparts(pathdir);
		end % epochid

		%% methods overriding NSD_FILETREE
	
		function [epochfiles] = selectfilegroups(self)
			% SELECTFILEGROUPS - Return groups of files that will comprise epochs
			%
			% EPOCHFILES = SELECTFILEGROUPS(SELF)
			%
			% Return the files that comprise epochs.
			%
			% EPOCHFILES{n} will be a cell list of the files in epoch n.
			%
			% For NSD_FILETREE_EPOCHDIR, this uses the file matching parameters in all
			% subdirectories within the experiment (at a folder depth of 1; that is, it doesn't
			% search folders in folders).
			%
			% See also: NSD_FILETREE/SETFILEPARAMETERS
			%
				exp_path = self.path();
				epochfiles = findfilegroups(exp_path, self.fileparameters.filematch,...
					'SearchParent',0,'SearchDepth',1);
		end % selectfilegroups

	end % methods
end

