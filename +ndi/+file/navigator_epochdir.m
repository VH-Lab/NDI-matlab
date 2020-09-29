% NDI_FILENAVIGATOR_EPOCHDIR - Create a new NDI_FILENAVIGATOR_EPOCHDIR object
%
%  DT = FILENAVIGATOR_EPOCHDIR(EXP, FILETYPE)   
%
%  Creates a new file tree object with the session name 
%  This class in inhereted from filenavigator and with epochdir organization
%

classdef navigator_epochdir < ndi.file.navigator
	properties
	end

	methods

		function obj = navigator_epochdir(varargin)
		% ndi.file.navigator_epochdir - Create a new ndi.file.navigator_epochdir object that is associated with an session and device
		%
		%   OBJ = ndi.file.navigator_epochdir(EXP, [FILEPARAMETERS, EPOCHPROBEMAP_CLASS, EPOCHPROBEMAP_FILEPARAMETERS])
		%
		% Creates a new ndi.file.navigator_epochdir object that negotiates the data tree of device's data that is
		% stored in an session EXP.
		%
		% (document FILEPARAMETERS)
		%
		% Inputs: EXP - an ndi.session.base ; FILEPARAMETERS - the files that are recorded in each epoch
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see ndi.file.navigator/SETFILEPARAMETERS for description)
		%      EPOCHPROBEMAP_CLASS: the class of epoch_record to be used; 'ndi.daq.metadata.epochprobemap_daqsystem' is used by default
		%      EPOCHPROBEMAP_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS). By default, the file location
		%          specified in ndi.file.navigator/EPOCHPROBEMAPFILENAME is used
		%
		% Output: OBJ - an ndi.file.navigator_epochdir object
		%
		% See also: ndi.session.base, ndi.daq.system
		%
			obj = obj@ndi.file.navigator(varargin{:});
		end

		% in NDI_BASE, need to change epochprobemapfilename to defaultepochprobemapfilename

		%% methods overriding ndi.epoch.epochset

		function id = epochid(ndi_filenavigator_epochdir_obj, epoch_number, epochfiles)
		% EPOCHID = Get the epoch identifier for a particular epoch
		%
		% ID = EPOCHID(NDI_FILENAVIGATOR_EPOCHDIR_OBJ, EPOCH_NUMBER, [EPOCHFILES])
		%
		% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
		% For the ndi.file.navigator_epochdir object, each EPOCH is organized in its own subdirectory,
		% and the epoch identifier is the _name_ of the subdirectory.
		%
		% For example, if my device has a file tree that reads files with extension .dat,
		% the session directory is
		%
		% mysession/
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

		%% methods overriding ndi.file.navigator
	
		function [epochfiles] = selectfilegroups(ndi_filenavigator_epochdir_obj)
			% SELECTFILEGROUPS - Return groups of files that will comprise epochs
			%
			% EPOCHFILES = SELECTFILEGROUPS(NDI_FILENAVIGATOR_EPOCHDIR_OBJ)
			%
			% Return the files that comprise epochs.
			%
			% EPOCHFILES{n} will be a cell list of the files in epoch n.
			%
			% For ndi.file.navigator_epochdir, this uses the file matching parameters in all
			% subdirectories within the session (at a folder depth of 1; that is, it doesn't
			% search folders in folders).
			%
			% See also: ndi.file.navigator/SETFILEPARAMETERS
			%
				exp_path = ndi_filenavigator_epochdir_obj.path();
				epochfiles = findfilegroups(exp_path, ndi_filenavigator_epochdir_obj.fileparameters.filematch,...
					'SearchParent',0,'SearchDepth',1);
		end % selectfilegroups

	end % methods
end
