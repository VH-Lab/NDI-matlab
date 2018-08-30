classdef nsd_filetree < nsd_base & nsd_epochset_param
	% NSD_FILETREE - object class for accessing files on disk

	properties (GetAccess=public, SetAccess=protected)
		experiment                    % The NSD_EXPERIMENT to be examined (handle)
		fileparameters                % The parameters for finding files (see NSD_FILETREE/SETFILEPARAMETERS)
		epochcontents_fileparameters  % The parameters for finding the epochcontents files (see NSD_FILETREE/SETEPOCHCONTENTSFILEPARAMETERS)
	end

	methods
	        function obj = nsd_filetree(experiment_, fileparameters_, epochcontents_class_, epochcontents_fileparameters_)
		% NSD_FILETREE - Create a new NSD_FILETREE object that is associated with an experiment and iodevice
		%
		%   OBJ = NSD_FILETREE(EXPERIMENT, [ FILEPARAMETERS, EPOCHCONTENTS_CLASS, EPOCHCONTENTS_FILEPARAMETERS])
		%
		% Creates a new NSD_FILETREE object that negotiates the data tree of iodevice's data that is
		% stored at the file path PATH.
		%
		% Inputs:
		%      EXPERIMENT: an NSD_EXPERIMENT
		% Optional inputs:
		%      FILEPARAMETERS: the files that are recorded in each epoch of DEVICE in this
		%          data tree style (see NSD_FILETREE/SETFILEPARAMETERS for description)
		%      EPOCHCONTENTS_CLASS: the class of epoch_record to be used; 'nsd_epochcontents_iodevice' is used by default
		%      EPOCHCONTENTS_FILEPARAMETERS: the file parameters to search for the epoch record file among the files
		%          present in each epoch (see NSD_FILETREE/SETEPOCHCONTENTSFILEPARAMETERS). By default, the file location
		%          specified in NSD_FILETREE/EPOCHCONTENTSFILENAME is used
		%
		% Output: OBJ - an NSD_FILETREE object
		%
		% See also: NSD_EXPERIMENT
		%

			if nargin>0,
				if ~isa(experiment_,'nsd_experiment'),
					error(['experiement must be an NSD_EXPERIMENT object']);
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
				obj.epochcontents_class = epochcontents_class_;
			else,
				obj.epochcontents_class = 'nsd_epochcontents_iodevice';
			end;

			if nargin > 3,
				obj = obj.setepochcontentsfileparameters(epochcontents_fileparameters_);
			else,
				obj.epochcontents_fileparameters = {};
			end;
		end;

		%% functions that used to override HANDLE

		function b = eq(nsd_filetree_obj_a, nsd_filetree_obj_b)
			% EQ - determines whether two NSD_FILETREE objects are equivalent
			%
			% B = EQ(NSD_FILETREE_OBJ_A, NSD_FILETREE_OBJ_B)
			%
			% Returns 1 if the NSD_FILETREE objects are equivalent, and 0 otherwise.
			% This equivalency does not depend on NSD_FILETREE_OBJ_A and NSD_FILETREE_OBJ_B are 
			% the same HANDLE objects. They can be equivalent and occupy different places in memory.
				parameternames = {'experiment','fileparameters','epochcontents_class','epochcontents_fileparameters'};
				b = 1;
				for i=1:numel(parameternames),
					b = b & eqlen(getfield(nsd_filetree_obj_a,parameternames{i}),getfield(nsd_filetree_obj_b,parameternames{i}));
					if ~b,
						break; % can stop checking
					end;
				end
		end % eq()

		%% functions that override NSD_BASE

		function [data, fieldnames] = stringdatatosave(nsd_filetree_obj)
			% STRINGDATATOSAVE - Returns a set of strings to write to file to save object information
			%
			% [DATA,FIELDNAMES] = STRINGDATATOSAVE(NSD_FILETREE_OBJ)
			%
			% Return a cell array of strings to save to the objectfilename.
			%
			% FIELDNAMES is a set of names of the fields/properties of the object
			% that are being stored.
			%
			% For NSD_FILETREE, this returns file parameters, epochcontents, and epochcontents_fileparameters.
			%
			% Note: NSD_FILETREE objects do not save their NSD_EXPERIMENT property EXPERIMENT. Call
			% SETPROPERTIES after reading an NSD_FILETREE from disk to install the NSD_EXPERIMENT.
			%
			% Developer note: If you create a subclass of NSD_FILETREE with properties, it is recommended
			% that you implement your own version of this method. If you have only properties that can be stored
			% efficiently as strings, then you will not need to include a WRITEOBJECTFILE method.
			%
				[data,fieldnames] = stringdatatosave@nsd_base(nsd_filetree_obj);
				if isstruct(nsd_filetree_obj.fileparameters),
					fp = cell2str(nsd_filetree_obj.fileparameters.filematch);
				else,
					fp = [];
				end

				if isstruct(nsd_filetree_obj.epochcontents_fileparameters),
					efp = cell2str(nsd_filetree_obj.epochcontents_fileparameters.filematch);
				else,
					efp = [];
				end

				data{end+1} = fp;
				fieldnames{end+1} = '$fileparameters';
				data{end+1} = nsd_filetree_obj.epochcontents_class;
				fieldnames{end+1} = 'epochcontents_class';
				data{end+1} = efp;
				fieldnames{end+1} = '$epochcontents_fileparameters';
		end % stringdatatosave

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

		%% functions that override the methods of NSD_EPOCHSET_PARAM

		function [et, all_epochs] = epochtable(nsd_filetree_obj)
			% EPOCHTABLE - Return an epoch table for NSD_FILETREE
			%
                        % ET = EPOCHTABLE(NSD_EPOCHSET_OBJ)
                        %
                        % ET is a structure array with the following fields:
                        % Fieldname:                | Description
                        % ------------------------------------------------------------------------
                        % 'epoch_number'            | The number of the epoch (may change)
                        % 'epoch_id'                | The epoch ID code (will never change once established)
                        %                           |   This uniquely specifies the epoch.
			% 'epochcontents'           | The epochcontents object from each epoch
                        % 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
                        %                           |   It contains fields 'underlying', 'epoch_number', 'epoch_id', and 'epochcontents'
			%                           |   'underlying' contains the file list for each epoch; 'epoch_id' and 'epoch_number'
			%                           |   match those of NSD_FILETREE_OBJ

				all_epochs = nsd_filetree_obj.selectfilegroups();

				ue = emptystruct('underlying','epoch_number','epoch_id','epochcontents');
				et = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');

				for i=1:numel(all_epochs),
					et_here = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
					et_here(1).underlying_epochs = ue;
					et_here(1).underlying_epochs(1).underlying = all_epochs{i};
					et_here(1).underlying_epochs(1).epoch_id = epochid(nsd_filetree_obj, i, all_epochs{i});
					et_here(1).underlying_epochs(1).epoch_number = i;
					et_here(1).epoch_number = i;
					et_here(1).epochcontents = getepochcontents(nsd_filetree_obj,i);
					et_here(1).epoch_id = epochid(nsd_filetree_obj, i, all_epochs{i});
					et(end+1) = et_here;
				end

		end % epochtable

		function id = epochid(nsd_filetree_obj, epoch_number, epochfiles)
			% EPOCHID - Get the epoch identifier for a particular epoch
			%
			% ID = EPOCHID (NSD_FILETREE_OBJ, EPOCH_NUMBER)
			%
			% Returns the epoch identifier string for the epoch EPOCH_NUMBER.
			% If it doesn't exist, it is created.
			%
			% 
				if nargin<3,
					epochfiles = getepochfiles(nsd_filetree_obj,epoch_number);
				end

				eidfname = epochidfilename(nsd_filetree_obj, epoch_number, epochfiles);

				if exist(eidfname,'file'),
					id = text2cellstr(eidfname);
					id = id{1};
				else,
					id = ['epoch_' num2hex(now) '_' num2hex(rand)];
					str2text(eidfname,id);
				end
		end %epochid()

		function eidfname = epochidfilename(nsd_filetree_obj, number, epochfiles)
			% EPOCHCONTENTSFILENAME - return the file path for the NSD_EPOCHCONTENTS_IODEVICE file for an epoch
			%
			% ECFNAME = EPOCHCONTENTSFILENAME(NSD_FILETREE_OBJ, NUMBER)
			%
			% Returns the EPOCHCONTENTSFILENAME for the NSD_IODEVICE NSD_DEVICE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated.
			%
			% In the base class, NSD_EPOCHCONTENTS_IODEVICE data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the NSD_EPOCHCONTENTS_IODEVICE data is stored as 'PATH/.MYFILENAME.ext.epochid.nsd.'.
			%
				fmstr = filematch_hashstring(nsd_filetree_obj);
				if nargin<3, % undocumented 3rd argument
					epochfiles = nsd_filetree_obj.getepochfiles_number(number);
				end
				if isempty(epochfiles),
					error(['No files in epoch number ' nsd_filetree_obj.epoch2str(number) '.']);
				else,
					[parentdir,filename]=fileparts(epochfiles{1});
					eidfname = [parentdir filesep '.' filename '.' fmstr '.epochid.nsd'];
				end
		end % epochidfilename()

		function ecfname = epochcontentsfilename(nsd_filetree_obj, number)
			% EPOCHCONTENTSFILENAME - return the file name for the NSD_EPOCHCONTENTS_IODEVICE file for an epoch
			%
			% ECFNAME = EPOCHCONTENTSFILENAME(NSD_FILETREE_OBJ, NUMBER)
			%
			% Returns the EPOCHCONTENTSFILENAME for the NSD_FILETREE NSD_FILETREE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated. The file name is returned with
			% a full path. NUMBER cannot be an epoch_id.
			%
			% The file name is determined by examining if the user has specified any
			% EPOCHCONTENTS_FILEPARAMETERS; if not, then the DEFAULTEPOCHCONTENTSFILENAME is used.
			%
			% See also: NSD_FILETREE/SETEPOCHCONTENTSFILEPARAMETERS, NSD_FILETREE/DEFAULTEPOCHCONTENTSFILENAME
			%
				% default   
				ecfname = defaultepochcontentsfilename(nsd_filetree_obj, number);

				% see if we need to use a different name based on EPOCHCONTENTS_FILEPARAMETERS

				if ~isempty(nsd_filetree_obj.epochcontents_fileparameters),
					epochfiles = nsd_filetree_obj.getepochfiles_number(number);
					fn = {};
					for i=1:length(epochfiles),
						[pa,name,ext] = fileparts(epochfiles{i});
						fn{i} = [name ext];
					end;
					for i=1:numel(nsd_filetree_obj.epochcontents_fileparameters.filematch),
						tf = strcmp_substitution(nsd_filetree_obj.epochcontents_fileparameters.filematch{i}, fn);
						indexes = find(tf);
						if numel(indexes)>0,
							ecfname = epochfiles{indexes(1)};
							break;
						end;
					end
				end;
		end % epochcontentsfilename

		function ecfname = defaultepochcontentsfilename(nsd_filetree_obj, number)
			% DEFAULTEPOCHCONTENTSFILENAME - return the default file name for the NSD_EPOCHCONTENTS_IODEVICE file for an epoch
			%
			% ECFNAME = DEFAULTEPOCHCONTENTSFILENAME(NSD_FILETREE_OBJ, NUMBER)
			%
			% Returns the default EPOCHCONTENTSFILENAME for the NSD_IODEVICE NSD_DEVICE_OBJ for epoch NUMBER.
			% If there are no files in epoch NUMBER, an error is generated. NUMBER cannot be an epoch id.
			%
			% In the base class, NSD_EPOCHCONTENTS_IODEVICE data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the default NSD_EPOCHCONTENTS_IODEVICE data is stored as 'PATH/.MYFILENAME.ext.epochcontents.nsd.'.
			% This may be overridden if there is an EPOCHCONTENTS_FILEPARAMETERS set.
			%
			% See also: NSD_FILETREE/SETEPOCHCONTENTSFILEPARAMETERS
			%
			%
				fmstr = filematch_hashstring(nsd_filetree_obj);
				epochfiles = nsd_filetree_obj.getepochfiles_number(number);
				if isempty(epochfiles),
					error(['No files in epoch number ' nsd_filetree_obj.epoch2str(number) '.']);
				else,
					[parentdir,filename]=fileparts(epochfiles{1});
					ecfname = [parentdir filesep '.' filename '.' fmstr '.epochcontents.nsd'];
				end
		end % defaultepochcontentsfilename

		function etfname = epochtagfilename(nsd_filetree_obj, epoch_number_or_id, epochfiles)
			% EPOCHTAGFILENAME - return the file path for the tag file for an epoch
			%
			% ETFNAME = EPOCHTAGFILENAME(NSD_FILETREE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Returns the tag file name for the NSD_FILETREE NSD_FILETREE_OBJ for epoch EPOCH_NUMBER_OR_ID.
			% EPOCH_NUMBER_OR_ID can be an epoch number or an epoch id. If there are no files in epoch EPOCH_NUMBER_OR_ID,
			% an error is generated.
			%
			% In the base class, NSD_EPOCHCONTENTS_IODEVICE data is stored as a hidden file in the same directory
			% as the first epoch file. If the first file in the epoch file list is 'PATH/MYFILENAME.ext', then
			% the NSD_EPOCHCONTENTS_IODEVICE data is stored as 'PATH/.MYFILENAME.ext.[code].epochid.nsd.'.
			%
			%
				fmstr = filematch_hashstring(nsd_filetree_obj);
				if nargin<3, % undocumented 3rd argument
					epochfiles = getepochfiles(nsd_filetree_obj, epoch_number_or_id);
				end
				if isempty(epochfiles),
					error(['No files in epoch number ' nsd_filetree_obj.epoch2str(epoch_number_or_id) '.']);
				else,
					[parentdir,filename]=fileparts(epochfiles{1});
					etfname = [parentdir filesep '.' filename '.' fmstr '.epochtag.nsd'];
				end
		end % epochtagfilename()

		%% functions that set and return internal parameters of NSD_FILETREE

		function nsd_filetree_obj = setfileparameters(nsd_filetree_obj, thefileparameters)
			% SETFILEPARAMETERS - Set the fileparameters field of a NSD_FILETREE object
			%
			%  NSD_FILETREE_OBJ = SETFILEPARAMETERS(NSD_FILETREE_OBJ, THEFILEPARAMETERS)
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
				nsd_filetree_obj.fileparameters = thefileparameters;
		end %setfileparameters()

		function nsd_filetree_obj = setepochcontentsfileparameters(nsd_filetree_obj, theepochcontentsfileparameters)
			% SETEPOCHCONTENTSFILEPARAMETERS - Set the epoch record fileparameters field of a NSD_FILETREE object
			%
			%  NSD_FILETREE_OBJ = SETEPOCHCONTENTSFILEPARAMETERS(NSD_FILETREE_OBJ, THEEPOCHCONTENTSFILEPARAMETERS)
			%
			%  THEEPOCHCONTENTSFILEPARAMETERS is a string or cell list of strings that specifies the epoch record
			%  file. By default, if no parameters are specified, the epoch record file is located at:
			%   [EXP]/.nsd/device_name/epoch_NNNNNNNNN.nsderf, where [EXP] is the experiment's path.
			%
			%  However, one can pass search parameters that will search among all the file names returned by
			%  NSD_FILETREE/GETEPOCHS. The search parameter should be a regular expression or a set of regular
			%  expressions such as:
			%
			%         Example: theepochcontentsfileparameters = '.*\.ext\>'
			%         Example: theepochcontentsfileparameters = {'myfile1.ext1', 'myfile2.ext2'}
			%         Example: theepochcontentsfileparameters = {'#.ext1',  'myfile#.ext2'} (# is the same, unknown string)
			%
				if isa(theepochcontentsfileparameters,'char'),
					theepochcontentsfileparameters = {theepochcontentsfileparameters};
				end;
				if isa(theepochcontentsfileparameters,'cell'),
					theepochcontentsfileparameters = struct('filematch',{theepochcontentsfileparameters});
				end;
				nsd_filetree_obj.epochcontents_fileparameters = theepochcontentsfileparameters;
		end % setepochcontentsfileparameters()

		function thepath = path(nsd_filetree_obj)
			% PATH - Return the file path for the NSD_FILETREE object
			%
			% THEPATH = PATH(NSD_FILETREE_OBJ)
			%
			% Returns the path of the NSD_EXPERIMENT associated with the NSD_FILETREE object
			% NSD_FILETREE_OBJ.
			%
				if ~isa(nsd_filetree_obj.experiment,'nsd_experiment'),
					error(['No valid NSD_EXPERIMENT associated with this filetree object.']);
				else,
					thepath = nsd_filetree_obj.experiment.getpath;
				end
		end % path

		function [epochfiles] = selectfilegroups(nsd_filetree_obj)
			% SELECTFILEGROUPS - Return groups of files that will comprise epochs
			%
			% EPOCHFILES = SELECTFILEGROUPS(NSD_FILETREE_OBJ)
			%
			% Return the files that comprise epochs.
			%
			% EPOCHFILES{n} will be a cell list of the files in epoch n.
			%
			% For NSD_FILETREE, this simply uses the file matching parameters.
			%
			% See also: NSD_FILETREE/SETFILEPARAMETERS
			%
				exp_path = nsd_filetree_obj.path();
				epochfiles = findfilegroups(exp_path, nsd_filetree_obj.fileparameters.filematch);
		end % selectfilegroups

		function [fullpathfilenames, epochid] = getepochfiles(nsd_filetree_obj, epoch_number_or_id)
			% GETEPOCHFILES - Return the file paths for one recording epoch
			%
			%  [FULLPATHFILENAMES, EPOCHID] = GETEPOCHFILES(NSD_FILETREE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			%  Return the file names or file paths associated with one recording epoch of
			%  of an NSD_FILETREE_OBJ.
			%
			%  EPOCH_NUMBER_OR_ID  can either be a number of an epoch to return, or an epoch identifier (epoch id).
			%
			%  Requesting multiple epochs simultaneously:
			%  EPOCH_NUMBER_OR_ID can also be an array of numbers, in which case a cell array of cell arrays is 
			%  returned in FULLPATHFILENAMES, one entry per number in EPOCH_NUMBER_OR_ID.  Further, EPOCH_NUMBER_OR_ID
			%  can be a cell array of strings of multiple epoch identifiers; in this case, a cell array of cell
			%  arrays is returned in FULLPATHFILENAMES.
			%
			%  Uses the FILEPARAMETERS (see NSD_FILETREE/SETFILEPARAMETERS) to identify recording
			%  epochs under the EXPERIMENT path.
			%
			%  See also: GETEPOCHID
			%
				% developer note: possibility of caching this with some timeout

				[et,all_epochs] = nsd_filetree_obj.epochtable();

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
					out_of_bounds = find(epoch_number_or_id>numel(all_epochs));
					if ~isempty(out_of_bounds),
						error(['No epoch number ' nsd_filetree_obj.epoch2str(epoch_number_or_id(out_of_bounds)) ' found.']);
					end
					matches = epoch_number_or_id;
				else, % need to check IDs until we find all the epochs of interest
					et = nsd_filetree_obj.epochtable();
					matches = [];
					for i=1:numel(epoch_number_or_id),
						id_match = find(strcmpi(epoch_number_or_id{i},{et.epoch_id}));
						if isempty(id_match),
							error(['No such epochid ' epoch_number_or_id{i} '.']);
						end
						matches(i) = id_match;
					end
				end

				fullpathfilenames = all_epochs(matches);
				epochid = {et(matches).epoch_id};
					
				if ~multiple_outputs,
					fullpathfilenames = fullpathfilenames{1};
					epochid = epochid{1}; 
				end
				
		end % getepochfiles()

		function [fullpathfilenames] = getepochfiles_number(nsd_filetree_obj, epoch_number)
			% GETEPOCHFILES - Return the file paths for one recording epoch
			%
			%  [FULLPATHFILENAMES] = GETEPOCHFILES_NUMBER(NSD_FILETREE_OBJ, EPOCH_NUMBER)
			%
			%  Return the file names or file paths associated with one recording epoch.
			%
			%  EPOCH_NUMBER must be a number or array of epoch numbers. EPOCH_NUMBER cannot be
			%  an EPOCH_ID. If EPOCH_NUMBER is an array, then a cell array of cell arrays is returned in
			%  FULLPATHFILENAMES.
			%
			%  Uses the FILEPARAMETERS (see NSD_FILETREE/SETFILEPARAMETERS) to identify recording
			%  epochs under the EXPERIMENT path.
			%
			%  See also: GETEPOCHFILES
			%
				% developer note: possibility of caching this with some timeout
				% developer note: this function exists so you can get the epoch files without calling epochtable, which also
				%   needs to get the epoch files; infinite recursion happens

				all_epochs = nsd_filetree_obj.selectfilegroups();
				out_of_bounds = find(epoch_number>numel(all_epochs));
				if ~isempty(out_of_bounds),
					error(['No epoch number ' nsd_filetree_obj.epoch2str(epoch_number(out_of_bounds)) ' found.']);
				end

				fullpathfilenames = all_epochs(epoch_number);
				if numel(epoch_number)==1,
					fullpathfilenames = fullpathfilenames{1};
				end
		end % getepochfiles_number()

		function fmstr = filematch_hashstring(nsd_filetree_obj)
			% FILEMATCH_HASHSTRING - a computation to produce a (likely to be) unique string based on filematch
			%
			% FMSTR = FILEMATCH_HASHSTRING(NSD_FILETREE_OBJ)
			%
			% Returns a string that is based on a hash function that is computed on 
			% the concatenated text of the 'filematch' field of the 'fileparameters' property.
			%
			% Note: the function used is 'crc' (see PM_HASH)

				algo = 'crc';

				if isempty(nsd_filetree_obj.fileparameters),
					fmhash = [];
				else,
					if ischar(nsd_filetree_obj.fileparameters.filematch),
						fmhash = pm_hash(algo,nsd_filetree_obj.fileparameters.filematch);
					elseif iscell(nsd_filetree_obj.fileparameters.filematch), % is cell
						catstr = cat(2,nsd_filetree_obj.fileparameters.filematch);
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
