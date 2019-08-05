% NDI_FILENAVIGATOR_EPOCHDIR - Create a new NDI_FILENAVIGATOR_EPOCHDIR object
%
%  DT = FILENAVIGATOR_EPOCHDIR(EXP, FILETYPE)   
%
%  Creates a new file tree object with the experiment name 
%  This class in inhereted from filenavigator and with epochdir organization
%

classdef ndi_filenavigator_epochdir < ndi_filenavigator
	properties
	end

	methods

		function obj = ndi_filenavigator_epochdir(varargin)
		% NDI_FILENAVIGATOR_EPOCHDIR - Create a new NDI_FILENAVIGATOR_EPOCHDIR object that is associated with an experiment and device
		%
		%   OBJ = NDI_FILENAVIGATOR_EPOCHDIR(EXP, [FILEPARAMETERS, EPOCHCONTENTS_CLASS, EPOCHCONTENTS_FILEPARAMETERS])
		%
		% Creates a new NDI_FILENAVIGATOR_EPOCHDIR object that negotiates the data tree of device's data that is
		% stored in an experiment EXP.
		%
		% (document FILEPARAMETERS)
		%
		% Inputs: EXP - an NDI_EXPERIMENT ; FILEPARAMETERS - the files that are recorded in each epoch
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see NDI_FILENAVIGATOR/SETFILEPARAMETERS for description)
		%      EPOCHCONTENTS_CLASS: the class of epoch_record to be used; 'ndi_epochcontents_iodevice' is used by default
		%      EPOCHCONTENTS_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see NDI_FILENAVIGATOR/SETEPOCHCONTENTSFILEPARAMETERS). By default, the file location
		%          specified in NDI_FILENAVIGATOR/EPOCHCONTENTSFILENAME is used
		%
		% Output: OBJ - an NDI_FILENAVIGATOR_EPOCHDIR object
		%
		% See also: NDI_EXPERIMENT, NDI_IODEVICE
		%
			obj = obj@ndi_filenavigator(varargin{:});
		end

		% in NDI_BASE, need to change epochcontentsfilename to defaultepochcontentsfilename

		%% methods overriding NDI_BASE

			function [obj,properties_set] = setproperties(ndi_filenavigator_obj, properties, values)
			% SETPROPERTIES - set the properties of an NDI_FILENAVIGATOR object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NDI_FILENAVIGATOR_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NDI_FILENAVIGATOR_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NDI_FILENAVIGATOR_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
			% Developer note: when creating a subclass of NDI_FILENAVIGATOR that has its own properties that
			% need to be read/written from disk, copy this method SETPROPERTIES into the new class so that
			% you will be able to set all properties (this instance can only set properties of NDI_FILENAVIGATOR).
			%
				fn = fieldnames(ndi_filenavigator_obj);
				obj = ndi_filenavigator_obj;
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

		%% methods overriding NDI_EPOCHSET

		function id = epochid(ndi_filenavigator_epochdir_obj, epoch_number, epochfiles)
		% EPOCHID = Get the epoch identifier for a particular epoch
		%
		% ID = EPOCHID(NDI_FILENAVIGATOR_EPOCHDIR_OBJ, EPOCH_NUMBER, [EPOCHFILES])
		%
		% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
		% For the NDI_FILENAVIGATOR_EPOCHDIR object, each EPOCH is organized in its own subdirectory,
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
				epochfiles = getepochfiles(ndi_filenavigator_epochdir_obj, epoch_number);
			end
			[pathdir,filename] = fileparts(epochfiles{1});
			[abovepath, id] = fileparts(pathdir);
		end % epochid

		%% methods overriding NDI_FILENAVIGATOR
	
		function [epochfiles] = selectfilegroups(ndi_filenavigator_epochdir_obj)
			% SELECTFILEGROUPS - Return groups of files that will comprise epochs
			%
			% EPOCHFILES = SELECTFILEGROUPS(NDI_FILENAVIGATOR_EPOCHDIR_OBJ)
			%
			% Return the files that comprise epochs.
			%
			% EPOCHFILES{n} will be a cell list of the files in epoch n.
			%
			% For NDI_FILENAVIGATOR_EPOCHDIR, this uses the file matching parameters in all
			% subdirectories within the experiment (at a folder depth of 1; that is, it doesn't
			% search folders in folders).
			%
			% See also: NDI_FILENAVIGATOR/SETFILEPARAMETERS
			%
				exp_path = ndi_filenavigator_epochdir_obj.path();
				epochfiles = findfilegroups(exp_path, ndi_filenavigator_epochdir_obj.fileparameters.filematch,...
					'SearchParent',0,'SearchDepth',1);
		end % selectfilegroups

	end % methods
end

