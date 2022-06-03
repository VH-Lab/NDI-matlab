% ndi.file.navigator.itemizeddir - a file navigator for some epochs that are arranged in multiple subdirectories
%%
%  Creates a new file navigator object with the session name 
%  This class in inhereted from filenavigator and with epochdir organization
%

classdef itemizeddir < ndi.file.navigator
	properties
	end

	methods

		function obj = itemizeddir(varargin)
		% ndi.file.navigator.itemizeddir - Create a new ndi.file.navigator.itemizeddir object that is associated with an session and device
		%
		%   OBJ = ndi.file.navigator.itemizeddir(EXP, [FILEPARAMETERS, EPOCHPROBEMAP_CLASS, EPOCHPROBEMAP_FILEPARAMETERS])
		%
		% Creates a new ndi.file.navigator.epochdir object that negotiates the data tree of a device's data that is
		% stored in an session EXP.
		%
		% Inputs: EXP - an ndi.session ; FILEPARAMETERS - the files that are recorded in each epoch
		%      FILEPARAMETERS: the files that are recorded in each epoch. itemizeddir has a different
		%          set of inputs and outputs than ndi.file.navigator. See below.
		%      EPOCHPROBEMAP_CLASS: the class of epoch_record to be used; 'ndi.epoch.epochprobemap_daqsystem' is used by default
		%      EPOCHPROBEMAP_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS). By default, the file location
		%          specified in ndi.file.navigator/EPOCHPROBEMAPFILENAME is used
		%
		% Output: OBJ - an ndi.file.navigator.itemizeddir object
		%
		% FILEPARAMETERs notes: This type of file navigator identifies files that span multiple subdirectories in a very specific form.
		% As an example, the subdirectories 't00001', 't00001-001', 't00001-002', 't00001-003' form a set of subdirectories
		% that match the form 't\d{5}', where there is a t followed by 5 digits, and there are directories for each base number
		% that follow a dash and 3 more digits. 
		%
		% The FILEPARAMETERS for an ndi.file.navigator.itemizeddir should be of the following form:
		%  {subdir_regexp1, subdir_regexp2, base_regexp1, base_regexp2, ... '||', other_regexp1, other_regexp2, ...}
		%   where
		%      subdir_regexp1 is the primary pattern of subdirectories to be found
		%      subdir_regexp2 is the secondary pattern to be found; this can contain the string 'TOKEN' and
		%          the string will be replaced with tokens found from subdir_regexp1,
		%      base_regexpN are regular expressions for files in the base subdirectory,
		%     '||' is a required separator, and 
		%      other_regexpN are regular expression for files in the other directories
		%
		% For example, if FILEPARAMETERS = {'t\d{5}\s','TOKEN-\d{3}\s','reference.txt','.*\.smr\>','stims.mat','||',...
		%    '.*\.xml\>'} 
		% 
		% then the navigator will look for 
		%   a) matches of directory names that are a regular expression match for the first parameter; all directories
		%      to be examined will have a 'tab' appended, so there is a non-whitespace character at the end of each directory name
		%        (in this case, 't(*\d{5}\s)', matches t with 5 digits after, so items like 't00001',
		%         't00002','t00003' will match)
		%   b) matches of directory names that contain each token followed by a dash and 3 digits (and whitespace),
		%        (in this case, the first token is 't00001', and 't00001-001','t00001-002', etc. will match)
		%   c) files in the base/primary subdirectories (e.g., 't00001', 't00002', etc) that match base_regexp1, base_regexp2, etc.
		%        (in this case, there must be a file named 'reference.txt', a file that ends in '.smr', and a file called
		%         'stims.mat'). There might be no requirements for files to match the primary directory if the separator is given
		%         immediately after subdir_regexp2.
		%   d) files in the other/secondary directories (e.g., 't00001-001', 't00001-002', etc) that must match other_regexp1, etc.
		%        (in this case, there must be a file that ends in .xml). There might be no requirement for files to match the primary
		%        directory if there are no arguments given after the separator.
		%
		%
		% See also: ndi.session, ndi.daq.system, ndi.file.navigator, ndi.file.navigator.epochdir
		%
			obj = obj@ndi.file.navigator(varargin{:});
		end

		% in NDI_BASE, need to change epochprobemapfilename to defaultepochprobemapfilename

		%% methods overriding ndi.epoch.epochset

		function id = epochid(ndi_filenavigator_itemizeddir_obj, epoch_number, epochfiles)
		% EPOCHID = Get the epoch identifier for a particular epoch
		%
		% ID = EPOCHID(NDI_FILENAVIGATOR_ITEMIZEDDIR_OBJ, EPOCH_NUMBER, [EPOCHFILES])
		%
		% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
		% For the ndi.file.navigator.epochdir object, each EPOCH is organized in its own subdirectory,
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
				epochfiles = getepochfiles(ndi_filenavigator_itemizeddir_obj, epoch_number);
			end
			[pathdir,filename] = fileparts(epochfiles{1});
			[abovepath, id] = fileparts(pathdir);
		end % epochid

		%% methods overriding ndi.file.navigator
	
		function [epochfiles] = selectfilegroups(ndi_filenavigator_itemizeddir_obj)
			% SELECTFILEGROUPS - Return groups of files that will comprise epochs
			%
			% EPOCHFILES = SELECTFILEGROUPS(NDI_FILENAVIGATOR_EPOCHDIR_OBJ)
			%
			% Return the files that comprise epochs.
			%
			% EPOCHFILES{n} will be a cell list of the files in epoch n.
			%
			% For ndi.file.navigator.epochdir, this uses the file matching parameters in all
			% subdirectories within the session (at a folder depth of 1; that is, it doesn't
			% search folders in folders).
			%
			% See also: ndi.file.navigator/SETFILEPARAMETERS
			%
				exp_path = ndi_filenavigator_itemizeddir_obj.path();
				d = vlt.file.dirlist_trimdots(dir([exp_path filesep '*']));
				d_string = [strjoin(d,'\t') sprintf('\t')]; % tab separated, including end

				% find tokens for first directory match

				m_1 = regexp(d_string,ndi_filenavigator_itemizeddir_obj.fileparameters.filematch{1},'start');
				m_2 = regexp(d_string,ndi_filenavigator_itemizeddir_obj.fileparameters.filematch{1},'end');
				tokens = {};
				for i=1:numel(m_1),
					tokens{end+1} = strip(d_string(m_1(i):m_2(i)),'right',sprintf('\t'));
				end;
				tokens = unique(tokens);

				% find tokens for second directory match 

				tokens2 = {};
				for i=1:numel(tokens),
					tokens2{i} = {};
					pattern = strrep(ndi_filenavigator_itemizeddir_obj.fileparameters.filematch{2},'TOKEN',tokens{i});
					m_start_here = regexp(d_string,pattern,'start');
					m_end_here = regexp(d_string,pattern,'end');
					for j=1:numel(m_start_here),
						tokens2{i}{end+1} = strip(d_string(m_start_here(j):m_end_here(j)));
					end;
				end;

				separator = find(strcmp('||',ndi_filenavigator_itemizeddir_obj.fileparameters.filematch));
				base_parameters = ndi_filenavigator_itemizeddir_obj.fileparameters.filematch(3:separator-1);
				other_parameters = ndi_filenavigator_itemizeddir_obj.fileparameters.filematch(separator+1:end);

				epochfiles = {};
				for i=1:numel(tokens),
					goodmatch = 0;
					ef = vlt.file.findfilegroups([exp_path filesep tokens{1}],base_parameters,'SearchParent',1,'SearchDepth',0);
					% in order for epoch to match, there must be no base parameters or...
					% ... if there are base parameters, it should have returned some matches
					if numel(base_parameters)==0 | ( ~isempty(ef) ), 
						for j=1:numel(tokens2{i}),
							ef_here = vlt.file.findfilegroups([exp_path filesep tokens2{i}{j}],other_parameters,...
									'SearchParent',1,'SearchDepth',0);
							if numel(other_parameters==0) | ~isempty(ef_here), 
								goodmatch = 1; % we have at least one set that matches for this epoch
							end;
							ef = cat(1,ef{:},ef_here{:});
						end;
					else,
						goodmatch = 0;
					end;
					if goodmatch,
						epochfiles{end+1} = ef;
					end;
				end;
		end % selectfilegroups

		function ndi_filenavigator_itemizeddir_obj = setfileparameters(ndi_filenavigator_itemizeddir_obj, thefileparameters)
			% SETFILEPARAMETERS - Set the fileparameters field of a ndi.file.navigator object
			%
			%  NDI_FILENAVIGATOR_ITEMIZEDDIR_OBJ = SETFILEPARAMETERS(NDI_FILENAVIGATOR_ITEMIZEDDIR OBJ, THEFILEPARAMETERS)
			%
			% FILEPARAMETERs notes: This type of file navigator identifies files that span multiple subdirectories in a very specific form.
			% As an example, the subdirectories 't00001', 't00001-001', 't00001-002', 't00001-003' form a set of subdirectories
			% that match the form 't\d{5}', where there is a t followed by 5 digits, and there are directories for each base number
			% that follow a dash and 3 more digits. 
			%
			% The FILEPARAMETERS for an ndi.file.navigator.itemizeddir should be of the following form:
			%  {subdir_regexp1, subdir_regexp2, base_regexp1, base_regexp2, ... '||', other_regexp1, other_regexp2, ...}
			%   where
			%      subdir_regexp1 is the primary pattern of subdirectories to be found
			%      subdir_regexp2 is the secondary pattern to be found; this can contain the string 'TOKEN' and
			%          the string will be replaced with tokens found from subdir_regexp1,
			%      base_regexpN are regular expressions for files in the base subdirectory,
			%     '||' is a required separator, and 
			%      other_regexpN are regular expression for files in the other directories
			%
			% For example, if FILEPARAMETERS = {'t\d{5}\s','TOKEN-\d{3}\s','reference.txt','.*\.smr\>','stims.mat','||',...
			%    '.*\.xml\>} 
			% 
			% then the navigator will look for 
			%   a) matches of directory names that are a regular expression match for the first parameter; all directories
			%      to be examined will have a 'tab' appended, so there is a non-whitespace character at the end of each directory name
			%        (in this case, 't(*\d{5}\s)', matches t with 5 digits after, so items like 't00001',
			%         't00002','t00003' will match)
			%   b) matches of directory names that contain each token followed by a dash and 3 digits (and whitespace),
			%        (in this case, the first token is 't00001', and 't00001-001','t00001-002', etc. will match)
			%   c) files in the base/primary subdirectories (e.g., 't00001', 't00002', etc) that match base_regexp1, base_regexp2, etc.
			%        (in this case, there must be a file named 'reference.txt', a file that ends in '.smr', and a file called
			%         'stims.mat'). There might be no requirements for files to match the primary directory if the separator is given
			%         immediately after subdir_regexp2.
			%   d) files in the other/secondary directories (e.g., 't00001-001', 't00001-002', etc) that must match other_regexp1, etc.
			%        (in this case, there must be a file that ends in .xml). There might be no requirement for files to match the primary
			%        directory if there are no arguments given after the separator.
			%
			%
				if isstruct(thefileparameters),
					args_to_test = thefileparameters.filematch;
				else,
					args_to_test = thefileparameters;
				end;
				args_to_test,
				indexes = find(strcmp('||',args_to_test));
				if numel(indexes)~=1 | max(indexes)<2, 
					error(['A (single) separator (''||'') is required, must be 3rd argument or greater.']);
				end;
				ndi_filenavigator_itemizeddir_obj = setfileparameters@ndi.file.navigator(ndi_filenavigator_itemizeddir_obj, ...
					thefileparameters);
		end %setfileparameters()


	end % methods
end

