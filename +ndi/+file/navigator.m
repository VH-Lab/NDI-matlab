classdef navigator < ndi.ido & ndi.epoch.epochset.param & ndi.documentservice & ndi.database.ingestion_help
	% ndi.file.navigator - object class for accessing files on disk

	properties (GetAccess=public, SetAccess=protected)
		session                    % The ndi.session to be examined (handle)
		fileparameters                % The parameters for finding files (see ndi.file.navigator/SETFILEPARAMETERS)
		epochprobemap_fileparameters  % The parameters for finding the epochprobemap files (see ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS)
	end

	methods
	        function obj = navigator(session_, fileparameters_, epochprobemap_class_, epochprobemap_fileparameters_)
		% ndi.file.navigator - Create a new ndi.file.navigator object that is associated with an session and daqsystem
		%
		%   OBJ = ndi.file.navigator(SESSION, [ FILEPARAMETERS, EPOCHPROBEMAP_CLASS, EPOCHPROBEMAP_FILEPARAMETERS])
		%                 or
		%   OBJ = ndi.file.navigator(SESSION, NDI_FILENAVIGATOR_DOC_OBJ)
		%
		% Creates a new ndi.file.navigator object that negotiates the data tree of daqsystem's data that is
		% stored at the file path PATH.
		%
		% Inputs:
		%      SESSION: an ndi.session
		% Optional inputs:
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see ndi.file.navigator/SETFILEPARAMETERS for description)
		%      EPOCHPROBEMAP_CLASS: the class of epoch_record to be used; 'ndi.epoch.epochprobemap_daqsystem' is used by default
		%      EPOCHPROBEMAP_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS). By default, the file location
		%          specified in ndi.file.navigator/EPOCHPROBEMAPFILENAME is used
		%
		% Output: OBJ - an ndi.file.navigator object
		%
		% See also: ndi.session
		%

			if nargin==2 & isa(session_,'ndi.session') & isa(fileparameters_,'ndi.document'),
				filenavdoc = fileparameters_;
				% extract parameters from the document
				if ~isempty(filenavdoc.document_properties.filenavigator.fileparameters),
					fileparameters_ =      eval([filenavdoc.document_properties.filenavigator.fileparameters]);
				else,
					fileparameters_ = [];
				end;
				epochprobemap_class_ = filenavdoc.document_properties.filenavigator.epochprobemap_class;
				if ~isempty(filenavdoc.document_properties.filenavigator.epochprobemap_fileparameters)
					epochprobemap_fileparameters_ = eval([filenavdoc.document_properties.filenavigator.epochprobemap_fileparameters]);
				else,
					epochprobemap_fileparameters_ = [];
				end;
				obj.identifier = filenavdoc.document_properties.base.id;
			else,
				if nargin<4,
					epochprobemap_fileparameters_ = [];
				end;
				if nargin<3,
					epochprobemap_class_ = 'ndi.epoch.epochprobemap_daqsystem';
				end;
				if nargin<2,
					fileparameters_ = [];
				end;
				if nargin<1,
					session_ = [];
				end;
			end;

			% now we have our parameters defined, build the object

			if ~isempty(session_),
				if ~isa(session_,'ndi.session'),
					error(['experiement must be an ndi.session object']);
				else,
					obj.session= session_;
				end;
			else,
				obj.session=[];
			end;

			if ~isempty(fileparameters_),
				obj = obj.setfileparameters(fileparameters_);
			else,
				obj.fileparameters = {};
			end;
		
			if ~isempty(epochprobemap_class_),
				obj.epochprobemap_class = epochprobemap_class_;
			else,
				obj.epochprobemap_class = 'ndi.epoch.epochprobemap_daqsystem';
			end;

			if ~isempty(epochprobemap_fileparameters_),
				obj = obj.setepochprobemapfileparameters(epochprobemap_fileparameters_);
			else,
				obj.epochprobemap_fileparameters = {};
			end;

		end; % filenavigator()

		%% functions that used to override HANDLE

		function b = eq(ndi_filenavigator_obj_a, ndi_filenavigator_obj_b)
			% EQ - determines whether two ndi.file.navigator objects are equivalent
			%
			% B = EQ(NDI_FILENAVIGATOR_OBJ_A, NDI_FILENAVIGATOR_OBJ_B)
			%
			% Returns 1 if the ndi.file.navigator objects are equivalent, and 0 otherwise.
			% This equivalency does not depend on NDI_FILENAVIGATOR_OBJ_A and NDI_FILENAVIGATOR_OBJ_B are 
			% the same HANDLE objects. They can be equivalent and occupy different places in memory.
				parameternames = {'session','fileparameters','epochprobemap_class','epochprobemap_fileparameters'};
				b = 1;
				for i=1:numel(parameternames),
					b = b & eqlen(getfield(ndi_filenavigator_obj_a,parameternames{i}),getfield(ndi_filenavigator_obj_b,parameternames{i}));
					if ~b,
						break; % can stop checking
					end;
				end
		end % eq()

		%% functions that override NDI_BASE

		%% functions that override the methods of ndi.epoch.epochset.param

		function [cache,key] = getcache(ndi_filenavigator_obj)
			% GETCACHE - return the NDI_CACHE and key for ndi.file.navigator
			%
			% [CACHE,KEY] = GETCACHE(NDI_FILENAVIGATOR_OBJ)
			%
			% Returns the CACHE and KEY for the ndi.file.navigator object.
			%
			% The CACHE is returned from the associated session.
			% The KEY is the string 'filenavigator_' followed by the object's id.
			%
			% See also: ndi.file.navigator
			
				cache = [];
				key = [];
				if isa(ndi_filenavigator_obj.session,'handle'),
					cache = ndi_filenavigator_obj.session.cache;
					key = ['filenavigator_' ndi_filenavigator_obj.id()];
				end
		end

		function [et] = buildepochtable(ndi_filenavigator_obj)
			% EPOCHTABLE - Return an epoch table for ndi.file.navigator
			%
                        % ET = BUILDEPOCHTABLE(NDI_EPOCHSET_OBJ)
                        %
                        % ET is a structure array with the following fields:
                        % Fieldname:                | Description
                        % ------------------------------------------------------------------------
                        % 'epoch_number'            | The number of the epoch (may change)
                        % 'epoch_id'                | The epoch ID code (will never change once established)
                        %                           |   This uniquely specifies the epoch within the session.
			% 'epoch_session_id'           | The ID of the session that contains this epoch.
			% 'epochprobemap'           | The epochprobemap object from each epoch
			% 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
			% 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
			%                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
                        % 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
                        %                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochprobemap'
			%                           |   'underlying' contains the file list for each epoch; 'epoch_id' and 'epoch_number'
			%                           |   match those of NDI_FILENAVIGATOR_OBJ

				all_epochs = ndi_filenavigator_obj.selectfilegroups();

				ue = emptystruct('underlying','epoch_id','epoch_session_id','epochprobemap','epoch_clock');
				et = emptystruct('epoch_number','epoch_id','epoch_session_id','epochprobemap',...
					'epoch_clock','t0_t1','underlying_epochs');

				for i=1:numel(all_epochs),
					et_here = emptystruct('epoch_number','epoch_id','epoch_session_id',...
						'epochprobemap','underlying_epochs');
					et_here(1).underlying_epochs = ue;
					et_here(1).underlying_epochs(1).underlying = all_epochs{i};
					et_here(1).underlying_epochs(1).epoch_id = epochid(ndi_filenavigator_obj, i, all_epochs{i});
					et_here(1).underlying_epochs(1).epoch_session_id = ndi_filenavigator_obj.session.id();
					et_here(1).underlying_epochs(1).epoch_clock = {ndi.time.clocktype('no_time')}; % filenavigator does not keep time
					et_here(1).underlying_epochs(1).t0_t1 = {[NaN NaN]}; % filenavigator does not keep time
					et_here(1).epoch_number = i;
					et_here(1).epochprobemap = getepochprobemap(ndi_filenavigator_obj,i);
					et_here(1).epoch_clock = epochclock(ndi_filenavigator_obj,i);
					et_here(1).t0_t1 = t0_t1(ndi_filenavigator_obj,i);
					et_here(1).epoch_id = epochid(ndi_filenavigator_obj, i, all_epochs{i});
					et_here(1).epoch_session_id = ndi_filenavigator_obj.session.id();
					et(end+1) = et_here;
				end;
		end; % epochtable()

		function id = epochid(ndi_filenavigator_obj, epoch_number, epochfiles)
			% EPOCHID - Get the epoch identifier for a particular epoch
			%
			% ID = EPOCHID (NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER)
			%
			% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
			% If it doesn't exist, it is created.
			%
			% 
				if nargin<3,
					epochfiles = getepochfiles(ndi_filenavigator_obj,epoch_number);
				end

				eidfname = epochidfilename(ndi_filenavigator_obj, epoch_number, epochfiles);

				if exist(eidfname,'file'),
					id = text2cellstr(eidfname);
					id = id{1};
				else,
					id = ['epoch_' ndi.ido.unique_id()];
					str2text(eidfname,id);
				end
		end %epochid()

		function eidfname = epochidfilename(ndi_filenavigator_obj, number, epochfiles)
			% EPOCHPROBEMAPFILENAME - return the file path for the ndi.epoch.epochprobemap_daqsystem file for an epoch
			%
			% ECFNAME = EPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
			%
			% Returns the EPOCHPROBEMAPFILENAME for the ndi.daq.system NDI_DEVICE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated.
			%
			% In the base class, ndi.epoch.epochprobemap_daqsystem data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the ndi.epoch.epochprobemap_daqsystem data is stored as 'PATH/.MYFILENAME.ext.epochid.ndi.'.
			%
				fmstr = filematch_hashstring(ndi_filenavigator_obj);
				if nargin<3, % undocumented 3rd argument
					epochfiles = ndi_filenavigator_obj.getepochfiles_number(number);
				end
				if isempty(epochfiles),
					error(['No files in epoch number ' ndi_filenavigator_obj.epoch2str(number) '.']);
				else,
					[parentdir,filename]=fileparts(epochfiles{1});
					eidfname = [parentdir filesep '.' filename '.' fmstr '.epochid.ndi'];
				end
		end % epochidfilename()

		function ecfname = epochprobemapfilename(ndi_filenavigator_obj, number)
			% EPOCHPROBEMAPFILENAME - return the file name for the ndi.epoch.epochprobemap_daqsystem file for an epoch
			%
			% ECFNAME = EPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
			%
			% Returns the EPOCHPROBEMAPFILENAME for the ndi.file.navigator NDI_FILENAVIGATOR_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated. The file name is returned with
			% a full path. NUMBER cannot be an epoch_id.
			%
			% The file name is determined by examining if the user has specified any
			% EPOCHPROBEMAP_FILEPARAMETERS; if not, then the DEFAULTEPOCHPROBEMAPFILENAME is used.
			%
			% See also: ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS, ndi.file.navigator/DEFAULTEPOCHPROBEMAPFILENAME
			%
				% default   
				ecfname = defaultepochprobemapfilename(ndi_filenavigator_obj, number);

				% see if we need to use a different name based on EPOCHPROBEMAP_FILEPARAMETERS

				if ~isempty(ndi_filenavigator_obj.epochprobemap_fileparameters),
					epochfiles = ndi_filenavigator_obj.getepochfiles_number(number);
					fn = {};
					for i=1:length(epochfiles),
						[pa,name,ext] = fileparts(epochfiles{i});
						fn{i} = [name ext];
					end;
					for i=1:numel(ndi_filenavigator_obj.epochprobemap_fileparameters.filematch),
						tf = strcmp_substitution(ndi_filenavigator_obj.epochprobemap_fileparameters.filematch{i}, fn);
						indexes = find(tf);
						if numel(indexes)>0,
							ecfname = epochfiles{indexes(1)};
							break;
						end;
					end
				end;
		end % epochprobemapfilename

		function ecfname = defaultepochprobemapfilename(ndi_filenavigator_obj, number)
			% DEFAULTEPOCHPROBEMAPFILENAME - return the default file name for the ndi.epoch.epochprobemap_daqsystem file for an epoch
			%
			% ECFNAME = DEFAULTEPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
			%
			% Returns the default EPOCHPROBEMAPFILENAME for the ndi.daq.system NDI_DEVICE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated. NUMBER cannot be an epoch id.
			%
			% In the base class, ndi.epoch.epochprobemap_daqsystem data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the default ndi.epoch.epochprobemap_daqsystem data is stored as 'PATH/.MYFILENAME.ext.epochprobemap.ndi.'.
			% This may be overridden if there is an EPOCHPROBEMAP_FILEPARAMETERS set.
			%
			% See also: ndi.file.navigator/SETEPOCHPROBEMAPFILEPARAMETERS
			%
			%
				fmstr = filematch_hashstring(ndi_filenavigator_obj);
				epochfiles = ndi_filenavigator_obj.getepochfiles_number(number);
				if isempty(epochfiles),
					error(['No files in epoch number ' ndi_filenavigator_obj.epoch2str(number) '.']);
				else,
					[parentdir,filename]=fileparts(epochfiles{1});
					ecfname = [parentdir filesep '.' filename '.' fmstr '.epochprobemap.ndi'];
				end
		end % defaultepochprobemapfilename

		function etfname = epochtagfilename(ndi_filenavigator_obj, epoch_number_or_id, epochfiles)
			% EPOCHTAGFILENAME - return the file path for the tag file for an epoch
			%
			% ETFNAME = EPOCHTAGFILENAME(NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the tag file name for the ndi.file.navigator NDI_FILENAVIGATOR_OBJ for epoch EPOCH_NUMBER_OR_ID.
			% EPOCH_NUMBER_OR_ID can be an epoch number or an epoch id. If there are no files in epoch EPOCH_NUMBER_OR_ID,
			% an error is generated.
			%
			% In the base class, ndi.epoch.epochprobemap_daqsystem data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the ndi.epoch.epochprobemap_daqsystem data is stored as 'PATH/.MYFILENAME.ext.[code].epochid.ndi.'.
			%
			%
				fmstr = filematch_hashstring(ndi_filenavigator_obj);
				if nargin<3, % undocumented 3rd argument
					epochfiles = getepochfiles(ndi_filenavigator_obj, epoch_number_or_id);
				end
				if isempty(epochfiles),
					error(['No files in epoch number ' ndi_filenavigator_obj.epoch2str(epoch_number_or_id) '.']);
				else,
					[parentdir,filename]=fileparts(epochfiles{1});
					etfname = [parentdir filesep '.' filename '.' fmstr '.epochtag.ndi'];
				end
		end % epochtagfilename()

		%% functions that set and return internal parameters of ndi.file.navigator

		function ndi_filenavigator_obj = setfileparameters(ndi_filenavigator_obj, thefileparameters)
			% SETFILEPARAMETERS - Set the fileparameters field of a ndi.file.navigator object
			%
			%  NDI_FILENAVIGATOR_OBJ = SETFILEPARAMETERS(NDI_FILENAVIGATOR_OBJ, THEFILEPARAMETERS)
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
				ndi_filenavigator_obj.fileparameters = thefileparameters;
		end %setfileparameters()

		function ndi_filenavigator_obj = setepochprobemapfileparameters(ndi_filenavigator_obj, theepochprobemapfileparameters)
			% SETEPOCHPROBEMAPFILEPARAMETERS - Set the epoch record fileparameters field of a ndi.file.navigator object
			%
			%  NDI_FILENAVIGATOR_OBJ = SETEPOCHPROBEMAPFILEPARAMETERS(NDI_FILENAVIGATOR_OBJ, THEEPOCHPROBEMAPFILEPARAMETERS)
			%
			%  THEEPOCHPROBEMAPFILEPARAMETERS is a string or cell list of strings that specifies the epoch record
			%  file. By default, if no parameters are specified, the epoch record file is located at:
			%   [EXP]/.ndi/device_name/epoch_NNNNNNNNN.ndierf, where [EXP] is the session's path.
			%
			%  However, one can pass search parameters that will search among all the file names returned by
			%  ndi.file.navigator/GETEPOCHS. The search parameter should be a regular expression or a set of regular
			%  expressions such as:
			%
			%         Example: theepochprobemapfileparameters = '.*\.ext\>'
			%         Example: theepochprobemapfileparameters = {'myfile1.ext1', 'myfile2.ext2'}
			%         Example: theepochprobemapfileparameters = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
			%
				if isa(theepochprobemapfileparameters,'char'),
					theepochprobemapfileparameters = {theepochprobemapfileparameters};
				end;
				if isa(theepochprobemapfileparameters,'cell'),
					theepochprobemapfileparameters = struct('filematch',{theepochprobemapfileparameters});
				end;
				ndi_filenavigator_obj.epochprobemap_fileparameters = theepochprobemapfileparameters;
		end % setepochprobemapfileparameters()

		function thepath = path(ndi_filenavigator_obj)
			% PATH - Return the file path for the ndi.file.navigator object
			%
			% THEPATH = PATH(NDI_FILENAVIGATOR_OBJ)
			%
			% Returns the path of the ndi.session associated with the ndi.file.navigator object
			% NDI_FILENAVIGATOR_OBJ.
			%
				if ~isa(ndi_filenavigator_obj.session,'ndi.session'),
					error(['No valid ndi.session associated with this filenavigator object.']);
				else,
					thepath = ndi_filenavigator_obj.session.getpath;
				end
		end % path

		function [epochfiles] = selectfilegroups(ndi_filenavigator_obj)
			% SELECTFILEGROUPS - Return groups of files that will comprise epochs
			%
			% EPOCHFILES = SELECTFILEGROUPS(NDI_FILENAVIGATOR_OBJ)
			%
			% Return the files that comprise epochs.
			%
			% EPOCHFILES{n} will be a cell list of the files in epoch n.
			%
			% For ndi.file.navigator, this simply uses the file matching parameters.
			%
			% See also: ndi.file.navigator/SETFILEPARAMETERS
			%
				exp_path = ndi_filenavigator_obj.path();
				epochfiles = findfilegroups(exp_path, ndi_filenavigator_obj.fileparameters.filematch);
		end % selectfilegroups

		function [fullpathfilenames, epochid] = getepochfiles(ndi_filenavigator_obj, epoch_number_or_id)
			% GETEPOCHFILES - Return the file paths for one recording epoch
			%
			%  [FULLPATHFILENAMES, EPOCHID] = GETEPOCHFILES(NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER_OR_ID)
			%
			%  Return the file names or file paths associated with one recording epoch of
			%  of an NDI_FILENAVIGATOR_OBJ.
			%
			%  EPOCH_NUMBER_OR_ID  can either be a number of an epoch to return, or an epoch identifier (epoch id).
			%
			%  Requesting multiple epochs simultaneously:
			%  EPOCH_NUMBER_OR_ID can also be an array of numbers, in which case a cell array of cell arrays is 
			%  returned in FULLPATHFILENAMES, one entry per number in EPOCH_NUMBER_OR_ID.  Further, EPOCH_NUMBER_OR_ID
			%  can be a cell array of strings of multiple epoch identifiers; in this case, a cell array of cell
			%  arrays is returned in FULLPATHFILENAMES.
			%
			%  Uses the FILEPARAMETERS (see ndi.file.navigator/SETFILEPARAMETERS) to identify recording
			%  epochs under the SESSION path.
			%
			%  See also: EPOCHID
			%
				[et] = ndi_filenavigator_obj.epochtable();

				multiple_outputs = 0;
				useids = 0;
				if (isnumeric(epoch_number_or_id) & length(epoch_number_or_id)>1) | iscell(epoch_number_or_id),
					multiple_outputs = 1;
				end
				if ischar(epoch_number_or_id),
					epoch_number_or_id = {epoch_number_or_id};
				end;  % make sure we have consistent format
				if iscell(epoch_number_or_id),
					useids = 1;
				end

				% now resolve each entry in turn
				if ~useids,
					out_of_bounds = find(epoch_number_or_id>numel(et));
					if ~isempty(out_of_bounds),
						error(['No epoch number ' ndi_filenavigator_obj.epoch2str(epoch_number_or_id(out_of_bounds)) ' found.']);
					end
					matches = epoch_number_or_id;
				else, % need to check IDs until we find all the epochs of interest
					et = ndi_filenavigator_obj.epochtable();
					matches = [];
					for i=1:numel(epoch_number_or_id),
						id_match = find(strcmpi(epoch_number_or_id{i},{et.epoch_id}));
						if isempty(id_match),
							error(['No such epochid ' epoch_number_or_id{i} '.']);
						end
						matches(i) = id_match;
					end
				end

				fullpathfilenames = {};
				for i=1:numel(matches),
					fullpathfilenames{i} = et(matches(i)).underlying_epochs.underlying;
				end;
				epochid = {et(matches).epoch_id};
					
				if ~multiple_outputs,
					fullpathfilenames = fullpathfilenames{1};
					epochid = epochid{1}; 
				end
				
		end % getepochfiles()

		function [fullpathfilenames] = getepochfiles_number(ndi_filenavigator_obj, epoch_number)
			% GETEPOCHFILES - Return the file paths for one recording epoch
			%
			%  [FULLPATHFILENAMES] = GETEPOCHFILES_NUMBER(NDI_FILENAVIGATOR_OBJ, EPOCH_NUMBER)
			%
			%  Return the file names or file paths associated with one recording epoch.
			%
			%  EPOCH_NUMBER must be a number or array of epoch numbers. EPOCH_NUMBER cannot be
			%  an EPOCH_ID. If EPOCH_NUMBER is an array, then a cell array of cell arrays is returned in
			%  FULLPATHFILENAMES.
			%
			%  Uses the FILEPARAMETERS (see ndi.file.navigator/SETFILEPARAMETERS) to identify recording
			%  epochs under the SESSION path.
			%
			%  See also: GETEPOCHFILES
			%
				% developer note: possibility of caching this with some timeout
				% developer note: this function exists so you can get the epoch files without calling epochtable, which also
				%   needs to get the epoch files; infinite recursion happens

				all_epochs = ndi_filenavigator_obj.selectfilegroups();
				out_of_bounds = find(epoch_number>numel(all_epochs));
				if ~isempty(out_of_bounds),
					error(['No epoch number ' ndi_filenavigator_obj.epoch2str(epoch_number(out_of_bounds)) ' found.']);
				end

				fullpathfilenames = all_epochs(epoch_number);
				if numel(epoch_number)==1,
					fullpathfilenames = fullpathfilenames{1};
				end
		end % getepochfiles_number()

		function fmstr = filematch_hashstring(ndi_filenavigator_obj)
			% FILEMATCH_HASHSTRING - a computation to produce a (likely to be) unique string based on filematch
			%
			% FMSTR = FILEMATCH_HASHSTRING(NDI_FILENAVIGATOR_OBJ)
			%
			% Returns a string that is based on a hash function that is computed on 
			% the concatenated text of the 'filematch' field of the 'fileparameters' property.
			%
			% Note: the function used is 'crc' (see PM_HASH)

				algo = 'crc';
				algo = 'MD5';

				if isempty(ndi_filenavigator_obj.fileparameters),
					fmhash = [];
				else,
					if ischar(ndi_filenavigator_obj.fileparameters.filematch),
						fmhash = DataHash(uint8(ndi_filenavigator_obj.fileparameters.filematch),'bin',algo,'hex');
						%fmhash = pm_hash(algo,ndi_filenavigator_obj.fileparameters.filematch); % out of date
					elseif iscell(ndi_filenavigator_obj.fileparameters.filematch), % is cell
						catstr = cell2str(ndi_filenavigator_obj.fileparameters.filematch);
						%catstr = cat(2,ndi_filenavigator_obj.fileparameters.filematch);
						%fmhash = pm_hash(algo,catstr); % out of date
						fmhash = DataHash(uint8(catstr),'bin',algo,'hex');
					else,
						error(['unexpected datatype for fileparameters.filematch.']);
					end
				end

				fmstr = fmhash;
			end

		function ndi_filenavigator_obj=setsession(ndi_filenavigator_obj, session)
			% SETSESSION - set the SESSION for an ndi.file.navigator object
			%
			% NDI_FILENAVIGATOR_OBJ = SETSESSION(NDI_FILENAVIGATOR_OBJ, SESSION)
			%
			% Set the SESSION property of an ndi.file.navigator object
			%
				ndi_filenavigator_obj.session = session;
		end; % setsession()

		%% functions that override ndi.database.ingestion_helper


                function cname = ingestion_class(ingestion_help_obj)
 			% INGESTION_CLASS - the name of the ingestion class for this object
			%
			% CNAME = INGESTION_CLASS(INGESTION_HELP_OBJ)
			%
			% Returns the class name of the object that should be created if this
			% object class is ingested into the database (and won't have access to any raw
			% data).
			%
				cname = 'ndi.file.navigator.ingest';
                end; % ingestion_class()


		%% functions that override ndi.documentservice
		function ndi_document_obj = newdocument(ndi_filenavigator_obj)
			% NEWDOCUMENT - create an ndi.document that is based on an ndi.file.navigator object
			%
			% NDI_DOCUMENT_OBJ = NEWDOCUMENT(NDI_FILENAVIGATOR_OBJ)
			%
			% Creates an ndi.document of type 'filenavigator.json'
			%
				filenavigator_structure.ndi_filenavigator_class = class(ndi_filenavigator_obj);
				if ~isempty(ndi_filenavigator_obj.fileparameters),
					filenavigator_structure.fileparameters = cell2str(ndi_filenavigator_obj.fileparameters.filematch); % convert to a string
				else,
					filenavigator_structure.fileparameters = '';
				end;
				filenavigator_structure.epochprobemap_class = ndi_filenavigator_obj.epochprobemap_class;
				if ~isempty(ndi_filenavigator_obj.epochprobemap_fileparameters),
					% convert to string
					filenavigator_structure.epochprobemap_fileparameters = ...
						cell2str(ndi_filenavigator_obj.epochprobemap_fileparameters.filematch); 
				else,
					filenavigator_structure.epochprobemap_fileparameters = '';
				end;
				
				ndi_document_obj = ndi.document('daq/filenavigator.json',...
					'filenavigator',filenavigator_structure,...
					'base.id', ndi_filenavigator_obj.id(),...
					'base.session_id', ndi_filenavigator_obj.session.id());
		end; % newdocument()

		function sq = searchquery(ndi_filenavigator_obj)
			% SEARCHQUERY - create a search query that will search for this object
			%
			% SQ = SEARCHQUERY(NDI_FILENAVIGATOR_OBJ)
			%
			% Returns a database search query for this ndi.file.navigator object.
			%
				sq = ndi.query('base.id','exact_string',ndi_filenavigator_obj.id(),'') & ...
					ndi.query('base.session_id', 'exact_string', ndi_filenavigator_obj.session.id(), '');
		end; % 
	end % methods

end % classdef
