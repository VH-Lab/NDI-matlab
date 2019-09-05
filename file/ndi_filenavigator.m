classdef ndi_filenavigator < ndi_base & ndi_epochset_param
	% NDI_FILENAVIGATOR - object class for accessing files on disk

	properties (GetAccess=public, SetAccess=protected)
		experiment                    % The NDI_EXPERIMENT to be examined (handle)
		fileparameters                % The parameters for finding files (see NDI_FILENAVIGATOR/SETFILEPARAMETERS)
		epochprobemap_fileparameters  % The parameters for finding the epochprobemap files (see NDI_FILENAVIGATOR/SETEPOCHPROBEMAPFILEPARAMETERS)
	end

	methods
	        function obj = ndi_filenavigator(experiment_, fileparameters_, epochprobemap_class_, epochprobemap_fileparameters_)
		% NDI_FILENAVIGATOR - Create a new NDI_FILENAVIGATOR object that is associated with an experiment and daqsystem
		%
		%   OBJ = NDI_FILENAVIGATOR(EXPERIMENT, [ FILEPARAMETERS, EPOCHPROBEMAP_CLASS, EPOCHPROBEMAP_FILEPARAMETERS])
		%
		% Creates a new NDI_FILENAVIGATOR object that negotiates the data tree of daqsystem's data that is
		% stored at the file path PATH.
		%
		% Inputs:
		%      EXPERIMENT: an NDI_EXPERIMENT
		% Optional inputs:
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see NDI_FILENAVIGATOR/SETFILEPARAMETERS for description)
		%      EPOCHPROBEMAP_CLASS: the class of epoch_record to be used; 'ndi_epochprobemap_daqsystem' is used by default
		%      EPOCHPROBEMAP_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see NDI_FILENAVIGATOR/SETEPOCHPROBEMAPFILEPARAMETERS). By default, the file location
		%          specified in NDI_FILENAVIGATOR/EPOCHPROBEMAPFILENAME is used
		%
		% Output: OBJ - an NDI_FILENAVIGATOR object
		%
		% See also: NDI_EXPERIMENT
		%

			if nargin>0,
				if ~isa(experiment_,'ndi_experiment'),
					error(['experiement must be an NDI_EXPERIMENT object']);
				else,
					obj.experiment= experiment_;
				end;
			else,
				obj.experiment=[];
			end;

			if nargin > 1,
				obj = obj.setfileparameters(fileparameters_);
			else,
				obj.fileparameters = {};
			end;

			if nargin > 2,
				obj.epochprobemap_class = epochprobemap_class_;
			else,
				obj.epochprobemap_class = 'ndi_epochprobemap_daqsystem';
			end;

			if nargin > 3,
				obj = obj.setepochprobemapfileparameters(epochprobemap_fileparameters_);
			else,
				obj.epochprobemap_fileparameters = {};
			end;
		end;

		%% functions that used to override HANDLE

		function b = eq(ndi_filenavigator_obj_a, ndi_filenavigator_obj_b)
			% EQ - determines whether two NDI_FILENAVIGATOR objects are equivalent
			%
			% B = EQ(NDI_FILENAVIGATOR_OBJ_A, NDI_FILENAVIGATOR_OBJ_B)
			%
			% Returns 1 if the NDI_FILENAVIGATOR objects are equivalent, and 0 otherwise.
			% This equivalency does not depend on NDI_FILENAVIGATOR_OBJ_A and NDI_FILENAVIGATOR_OBJ_B are 
			% the same HANDLE objects. They can be equivalent and occupy different places in memory.
				parameternames = {'experiment','fileparameters','epochprobemap_class','epochprobemap_fileparameters'};
				b = 1;
				for i=1:numel(parameternames),
					b = b & eqlen(getfield(ndi_filenavigator_obj_a,parameternames{i}),getfield(ndi_filenavigator_obj_b,parameternames{i}));
					if ~b,
						break; % can stop checking
					end;
				end
		end % eq()

		%% functions that override NDI_BASE

		function [data, fieldnames] = stringdatatosave(ndi_filenavigator_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NDI_FILENAVIGATOR_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% For NDI_FILENAVIGATOR, this returns file parameters, epochprobemap, and epochprobemap_fileparameters.
			%
			% Note: NDI_FILENAVIGATOR objects do not save their NDI_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NDI_FILENAVIGATOR from disk to install the NDI_EXPERIMENT.
			%
			% Developer note: If you create a subclass of NDI_FILENAVIGATOR with properties, it is recommended
			% that you implement your own version of this method. If you have only properties that can be stored
			% efficiently as strings, then you will not need to include a WRITEOBJECTFILE method.
			%
				[data,fieldnames] = stringdatatosave@ndi_base(ndi_filenavigator_obj);
				if isstruct(ndi_filenavigator_obj.fileparameters),
					fp = cell2str(ndi_filenavigator_obj.fileparameters.filematch);
				else,
					fp = [];
				end

				if isstruct(ndi_filenavigator_obj.epochprobemap_fileparameters),
					efp = cell2str(ndi_filenavigator_obj.epochprobemap_fileparameters.filematch);
				else,
					efp = [];
				end

				data{end+1} = fp;
				fieldnames{end+1} = '$fileparameters';
				data{end+1} = ndi_filenavigator_obj.epochprobemap_class;
				fieldnames{end+1} = 'epochprobemap_class';
				data{end+1} = efp;
				fieldnames{end+1} = '$epochprobemap_fileparameters';
		end % stringdatatosave

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
								case 'epochprobemap_fileparameters',
									if ~isempty(values{i}),
										fp = eval(values{i});
										obj = obj.setepochprobemapfileparameters(fp);
									else,
										obj.epochprobemap_fileparameters = [];
									end
								otherwise,
									error(['Do not know how to set property ' properties{i}(2:end) '.']);
							end
							properties_set{end+1} = properties{i}(2:end);
						end
					end
				end
		end % setproperties()

		%% functions that override the methods of NDI_EPOCHSET_PARAM

		function [cache,key] = getcache(ndi_filenavigator_obj)
			% GETCACHE - return the NDI_CACHE and key for NDI_FILENAVIGATOR
			%
			% [CACHE,KEY] = GETCACHE(NDI_FILENAVIGATOR_OBJ)
			%
			% Returns the CACHE and KEY for the NDI_FILENAVIGATOR object.
			%
			% The CACHE is returned from the associated experiment.
			% The KEY is the object's objectfilename.	
			%
			% See also: NDI_FILENAVIGATOR, NDI_BASE
			
				cache = [];
				key = [];
				if isa(ndi_filenavigator_obj.experiment,'handle'),
					cache = ndi_filenavigator_obj.experiment.cache;
					key = ndi_filenavigator_obj.objectfilename;
				end
		end

		function [et] = buildepochtable(ndi_filenavigator_obj)
			% EPOCHTABLE - Return an epoch table for NDI_FILENAVIGATOR
			%
                        % ET = BUILDEPOCHTABLE(NDI_EPOCHSET_OBJ)
                        %
                        % ET is a structure array with the following fields:
                        % Fieldname:                | Description
                        % ------------------------------------------------------------------------
                        % 'epoch_number'            | The number of the epoch (may change)
                        % 'epoch_id'                | The epoch ID code (will never change once established)
                        %                           |   This uniquely specifies the epoch.
			% 'epochprobemap'           | The epochprobemap object from each epoch
			% 'epoch_clock'             | A cell array of NDI_CLOCKTYPE objects that describe the type of clocks available
			% 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each NDI_CLOCKTYPE, the start and stop
			%                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
                        % 'underlying_epochs'       | A structure array of the ndi_epochset objects that comprise these epochs.
                        %                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochprobemap'
			%                           |   'underlying' contains the file list for each epoch; 'epoch_id' and 'epoch_number'
			%                           |   match those of NDI_FILENAVIGATOR_OBJ

				all_epochs = ndi_filenavigator_obj.selectfilegroups();

				ue = emptystruct('underlying','epoch_id','epochprobemap','epoch_clock');
				et = emptystruct('epoch_number','epoch_id','epochprobemap','epoch_clock','t0_t1','underlying_epochs');

				for i=1:numel(all_epochs),
					et_here = emptystruct('epoch_number','epoch_id','epochprobemap','underlying_epochs');
					et_here(1).underlying_epochs = ue;
					et_here(1).underlying_epochs(1).underlying = all_epochs{i};
					et_here(1).underlying_epochs(1).epoch_id = epochid(ndi_filenavigator_obj, i, all_epochs{i});
					et_here(1).underlying_epochs(1).epoch_clock = {ndi_clocktype('no_time')}; % filenavigator does not keep time
					et_here(1).underlying_epochs(1).t0_t1 = {[NaN NaN]}; % filenavigator does not keep time
					et_here(1).epoch_number = i;
					et_here(1).epochprobemap = getepochprobemap(ndi_filenavigator_obj,i);
					et_here(1).epoch_clock = epochclock(ndi_filenavigator_obj,i);
					et_here(1).t0_t1 = t0_t1(ndi_filenavigator_obj,i);
					et_here(1).epoch_id = epochid(ndi_filenavigator_obj, i, all_epochs{i});
					et(end+1) = et_here;
				end
		end % epochtable

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
					id = ['epoch_' ndi_unique_id];
					str2text(eidfname,id);
				end
		end %epochid()

		function eidfname = epochidfilename(ndi_filenavigator_obj, number, epochfiles)
			% EPOCHPROBEMAPFILENAME - return the file path for the NDI_EPOCHPROBEMAP_DAQSYSTEM file for an epoch
			%
			% ECFNAME = EPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
			%
			% Returns the EPOCHPROBEMAPFILENAME for the NDI_DAQSYSTEM NDI_DEVICE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated.
			%
			% In the base class, NDI_EPOCHPROBEMAP_DAQSYSTEM data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the NDI_EPOCHPROBEMAP_DAQSYSTEM data is stored as 'PATH/.MYFILENAME.ext.epochid.ndi.'.
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
			% EPOCHPROBEMAPFILENAME - return the file name for the NDI_EPOCHPROBEMAP_DAQSYSTEM file for an epoch
			%
			% ECFNAME = EPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
			%
			% Returns the EPOCHPROBEMAPFILENAME for the NDI_FILENAVIGATOR NDI_FILENAVIGATOR_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated. The file name is returned with
			% a full path. NUMBER cannot be an epoch_id.
			%
			% The file name is determined by examining if the user has specified any
			% EPOCHPROBEMAP_FILEPARAMETERS; if not, then the DEFAULTEPOCHPROBEMAPFILENAME is used.
			%
			% See also: NDI_FILENAVIGATOR/SETEPOCHPROBEMAPFILEPARAMETERS, NDI_FILENAVIGATOR/DEFAULTEPOCHPROBEMAPFILENAME
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
			% DEFAULTEPOCHPROBEMAPFILENAME - return the default file name for the NDI_EPOCHPROBEMAP_DAQSYSTEM file for an epoch
			%
			% ECFNAME = DEFAULTEPOCHPROBEMAPFILENAME(NDI_FILENAVIGATOR_OBJ, NUMBER)
			%
			% Returns the default EPOCHPROBEMAPFILENAME for the NDI_DAQSYSTEM NDI_DEVICE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated. NUMBER cannot be an epoch id.
			%
			% In the base class, NDI_EPOCHPROBEMAP_DAQSYSTEM data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the default NDI_EPOCHPROBEMAP_DAQSYSTEM data is stored as 'PATH/.MYFILENAME.ext.epochprobemap.ndi.'.
			% This may be overridden if there is an EPOCHPROBEMAP_FILEPARAMETERS set.
			%
			% See also: NDI_FILENAVIGATOR/SETEPOCHPROBEMAPFILEPARAMETERS
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
			% Returns the tag file name for the NDI_FILENAVIGATOR NDI_FILENAVIGATOR_OBJ for epoch EPOCH_NUMBER_OR_ID.
			% EPOCH_NUMBER_OR_ID can be an epoch number or an epoch id. If there are no files in epoch EPOCH_NUMBER_OR_ID,
			% an error is generated.
			%
			% In the base class, NDI_EPOCHPROBEMAP_DAQSYSTEM data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the NDI_EPOCHPROBEMAP_DAQSYSTEM data is stored as 'PATH/.MYFILENAME.ext.[code].epochid.ndi.'.
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

		%% functions that set and return internal parameters of NDI_FILENAVIGATOR

		function ndi_filenavigator_obj = setfileparameters(ndi_filenavigator_obj, thefileparameters)
			% SETFILEPARAMETERS - Set the fileparameters field of a NDI_FILENAVIGATOR object
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
			% SETEPOCHPROBEMAPFILEPARAMETERS - Set the epoch record fileparameters field of a NDI_FILENAVIGATOR object
			%
			%  NDI_FILENAVIGATOR_OBJ = SETEPOCHPROBEMAPFILEPARAMETERS(NDI_FILENAVIGATOR_OBJ, THEEPOCHPROBEMAPFILEPARAMETERS)
			%
			%  THEEPOCHPROBEMAPFILEPARAMETERS is a string or cell list of strings that specifies the epoch record
			%  file. By default, if no parameters are specified, the epoch record file is located at:
			%   [EXP]/.ndi/device_name/epoch_NNNNNNNNN.ndierf, where [EXP] is the experiment's path.
			%
			%  However, one can pass search parameters that will search among all the file names returned by
			%  NDI_FILENAVIGATOR/GETEPOCHS. The search parameter should be a regular expression or a set of regular
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
			% PATH - Return the file path for the NDI_FILENAVIGATOR object
			%
			% THEPATH = PATH(NDI_FILENAVIGATOR_OBJ)
			%
			% Returns the path of the NDI_EXPERIMENT associated with the NDI_FILENAVIGATOR object
			% NDI_FILENAVIGATOR_OBJ.
			%
				if ~isa(ndi_filenavigator_obj.experiment,'ndi_experiment'),
					error(['No valid NDI_EXPERIMENT associated with this filenavigator object.']);
				else,
					thepath = ndi_filenavigator_obj.experiment.getpath;
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
			% For NDI_FILENAVIGATOR, this simply uses the file matching parameters.
			%
			% See also: NDI_FILENAVIGATOR/SETFILEPARAMETERS
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
			%  Uses the FILEPARAMETERS (see NDI_FILENAVIGATOR/SETFILEPARAMETERS) to identify recording
			%  epochs under the EXPERIMENT path.
			%
			%  See also: EPOCHID
			%
				% developer note: possibility of caching this with some timeout -- 2018-08-31 we did it!!!

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
			%  Uses the FILEPARAMETERS (see NDI_FILENAVIGATOR/SETFILEPARAMETERS) to identify recording
			%  epochs under the EXPERIMENT path.
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

				if isempty(ndi_filenavigator_obj.fileparameters),
					fmhash = [];
				else,
					if ischar(ndi_filenavigator_obj.fileparameters.filematch),
						fmhash = pm_hash(algo,ndi_filenavigator_obj.fileparameters.filematch);
					elseif iscell(ndi_filenavigator_obj.fileparameters.filematch), % is cell
						catstr = cat(2,ndi_filenavigator_obj.fileparameters.filematch);
						fmhash = pm_hash(algo,catstr);
					else,
						error(['unexpected datatype for fileparameters.filematch.']);
					end
				end

				if ~isempty(fmhash),
					fmstr = num2hex(double(fmhash));
				end
			end

	end % methods

end % classdef