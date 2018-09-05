classdef nsd_synctable2 < nsd_base
% NSD_SYNCTABLE - a class for converting time across different epochs (Second generation NSD_SYNCTABLE)
%

	properties (SetAccess=protected,GetAccess=public),
		epochs % a cell array of epochtables
		device_rules % struct array of rules for mapping across devices 
		G  % adjacency matrix of clocks for construction of a graph
		bestrule % table entry of the best rule between two epochs
		experiment % NSD_EXPERIMENT object
	end % properties
	properties (SetAccess=protected,GetAccess=protected)
	end % properties
	methods
		function obj = nsd_synctable2(varargin)
			% NSD_SYNCTABLE - Creates a new NSD_SYNCTABLE object
			%
			% OBJ = NSD_SYNCTABLE()
			%
			% Creates an empty NSD_SYNCTABLE object.
			%
			% Can also be called with OBJ = NSD_SYNCTABLE(EXP) to install EXP as the NSD_EXPERIMENT object
			% (property 'experiment')
			%
			% Can also be called with OBJ = NSD_SYNCTABLE(FILENAME, 'OpenFile') to read the object from the
			% file FILENAME.
			%
			% Can also be called with OBJ = NSD_SYNCTABLE(FILENAME, 'OpenFileAndUpdate', EXP) to read the object from
			% the file FILENAME and then to update the CLOCK handles with the NSD_EXPERIMENT EXP.
			%
				obj=obj@nsd_base;
				obj.entries = emptystruct('clock1','clock2','rule','ruleparameters','cost','valid_range');
				obj.G = [];
				obj.clocks = {};
				obj.experiment = [];
				if nargin==1,
					obj.experiment = varargin{1};
				end
				if nargin==2,
					if strcmp(lower(varargin{2}),lower('OpenFile')),
						obj = obj.readobjectfile(varargin{1});
					end
				elseif nargin==3,
					if strcmp(lower(varargin{2}),lower('OpenFileAndUpdate')),
						obj = obj.readobjectfile(varargin{1});
						obj = obj.updatehandles(varargin{3});
					end
				end
		end % nsd_synctable()

		%% functions that override NSD_BASE:

		function [obj,properties_set] = setproperties(nsd_synctable_obj, properties, values)
			% SETPROPERTIES - set the properties of an NSD_DBLEAF object
			%
			% [OBJ,PROPERTIESSET] = SETPROPERTIES(NSD_SYNCTABLE_OBJ, PROPERTIES, VALUES)
			%
			% Given a cell array of string PROPERTIES and a cell array of the corresponding
			% VALUES, sets the fields in NSD_SYNCTABLE_OBJ and returns the result in OBJ.
			%
			% If any entries in PROPERTIES are not properties of NSD_SYNCTABLE_OBJ, then
			% that property is skipped.
			%
			% The properties that are actually set are returned in PROPERTIESSET.
			%
				fn = fieldnames(nsd_synctable_obj);
				obj = nsd_synctable_obj;
				properties_set = {};
				for i=1:numel(properties),
					if any(strcmp(properties{i},fn)) | any (strcmp(properties{i}(2:end),fn)),
						if properties{i}(1)~='$',
							eval(['obj.' properties{i} '= values{i};']);
							properties_set{end+1} = properties{i};
						else,
							eval(['obj.' properties{i}(2:end) '=' values{i} ';']);
							properties_set{end+1} = properties{i}(2:end);
						end
					end
				end
		end % setproperties()

		function writedata2objectfile(nsd_synctable_obj, fid)
			% WRITEDATA2OBJECTFILE - write NSD_SYNCTABLE object file data to the object file FID
			%
			% WRITEDATA2OBJECTFILE(NSD_SYNCTABLE_OBJ, FID)
			%
			% This function writes the data for the NSD_SYNCTABLE_OBJ to the object file      
			% identifier FID.
			%
			% This function assumes the FID is open for writing and it does not close the
			% the FID. This function is normally called by WRITEOBJECTFILE and is typically
			% an internal function.
			%
				saveStruct = nsd_synctable_obj.getsavestruct;

				saveStructString = struct2mlstr(saveStruct);
				count = fwrite(fid,saveStructString,'char');
				if count~=numel(saveStructString),
					error(['Error writing to the file ' filename '.']);
				end
		end % writedata2objectfile()

		function nsd_synctable_obj = readobjectfile(nsd_synctable_obj, filename)
			% READOBJECTFILE - read 
			%
			% NSD_SYNCTABLE_OBJ = READOBJECTFILE(NSD_SYNCTABLE_OBJ, FILENAME)
			%
			% Reads the NSD_SYNCTABLE_OBJ from the file FNAME (full path).
				fid = fopen(filename, 'rb');
				if fid<0,
					error(['Could not open the file ' filename ' for reading.']);
				end;
				saveStructString = char(fread(fid,Inf,'char'));
				saveStructString = saveStructString(:)'; % make sure we are a 'row'
				fclose(fid);
				saveStruct = mlstr2var(saveStructString);
				fn = fieldnames(saveStruct);
				values = {};
				for i=1:numel(fn), 
					values{i} = getfield(saveStruct,fn{i});
				end;
				nsd_synctable_obj = nsd_synctable_obj.setproperties(fn,values);
		end; % readobjectfile

		function fname = outputobjectfilename(nsd_synctable_obj)
			% OUTPUTOBJECTFILENAME - return the file name of an NSD_SYNCTABLE object
			%
			% FNAME = OUTPUTOBJECTFILENAME(NSD_SYNCTABLE_OBJ)
			%
			% Returns the filename (without parent directory) to be used to save the NSD_SYNCTABLE
			% object. In the NSD_SYNCTABLE class, it is [NSD_BASE_OBJ.objectfilename '.synctable.nsd']
			%
			%
				fname = [nsd_synctable_obj.objectfilename '.synctable.nsd'];
		end % outputobjectfilename()

		% novel methods:

		function [cache,key] = getcache(nsd_synctable_obj)
			% GETCACHE - return the NSD_CACHE and key for NSD_SYNCTABLE
			%
			% [CACHE,KEY] = GETCACHE(NSD_SYNCTABLE_OBJ)
			%
			% Returns the CACHE and KEY for the NSD_SYNCTABLE object.
			%
			% The CACHE is returned from the associated experiment (type NSD_EXPERIMENT).
			% The KEY is the object's objectfilename.
			%
			% See also: NSD_FILETREE, NSD_BASE

				cache = [];
				key = [];
				if isa(nsd_synctable_obj.experiment,'handle'),
					cache = nsd_synctable_obj.experiment.cache;
					key = nsd_synctable_obj.objectfilename;
				end
		end

		function nsd_synctable_obj = add(nsd_synctable_obj, clock1, clock2, rule, ruleparameters, cost, valid_range)
			% ADD - add a time conversion rule entry to an NSD_SYNCTABLE object
			%
			% NSD_SYNCTABLE_OBJ = ADD(NSD_SYNCTABLE_OBJ, CLOCK1, CLOCK2, ...
			%     RULE, RULEPARAMETERS, COST, VALID_RANGE) 
			%   or 
			% NSD_SYNCTABLE_OBJ = ADD(NSD_SYNCTABLE_OBJ, NSD_SYNCTABLE_STRUCT)
			%    (where NSD_SYNCTABLE_STRUCT is a struct with fieldnames 'clock1', 'clock2', etc.)
			%
			% Add an entry to the NSD_SYNCTABLE object NSD_SYNCTABLE_OBJ.
			% RULE should be one of the following rules with the associated RULEPARAMETERS:
			%
			% RULE:             | Description, RULEPARAMETERS
			% ----------------------------------------------------------
			% 'equal'           | The clocks are equal (no RULEPARAMETERS)
			% 'commontrigger'   | The devices acquire a common trigger signal.
			%                   | RULEPARAMETERS should be a struct with fields
			%                   |   clock1_channels: nsd_iodevice_string (e.g., 'mydev:mk1')
			%                   |   clock2_channels: nsd_iodevice_string (e.g., 'myotherdev:din1')
			% 'withindevice'    | Conversion from one clock within a device to a different clock
			%                   |   in the device (e.g., 'utc' to 'dev_local_time')
			%
			% COST should reflect the computational cost of performing the conversion.
			% The TIMECONVERT function attempts to minimize the cost of performing the
			% conversion from one clock to another.
			% As a rule of thumb, the following cost structure should be used:
			%
			% RULE:             | Cost 
			% -----------------------------
			% 'equal'           | 1
			% 'commontrigger'   | 10
			% 'withindevice'    | 3
			%
			% Whenever a new NSD_CLOCK_IODEVICE CLOCK1 or CLOCK2 is added to the tabe, and if those clocks
			% are of type 'utc', 'exp_global_time', or 'dev_global_time', and are associated with a
			% device, then additional entries are added that chart the implict 'withindevice' conversions.
			%
				if isstruct(clock1),
					mystruct = clock1;
				else,
					mystruct = var2struct('clock1','clock2','rule','ruleparameters','cost','valid_range');
				end

				index = (mystruct == nsd_synctable_obj.entries);
				if any(index),
					%warning('Identical entry already exists. No more work to do.');
					return;
				end

					% dis:one may say, why not add them and let computeadjacencymatrix find the redundency? not for now
				index1 = cellfun(@(x) eq(x,mystruct.clock1), nsd_synctable_obj.clocks);
				index2 = cellfun(@(x) eq(x,mystruct.clock2), nsd_synctable_obj.clocks);
				if isempty(find(index1)),
					nsd_synctable_obj.clocks{end+1} = clock1;
					index1(end+1) = 1;
				end
				if isempty(find(index2)),
					nsd_synctable_obj.clocks{end+1} = clock2;
					index2(end+1) = 1;
				end

				try,
					nsd_synctable_obj.entries(end+1) = mystruct;
					nsd_synctable_obj = computeadjacencymatrix(nsd_synctable_obj);
				catch,
					error(['Unable to add entry:' lasterr ]);
				end

				if isfield(nsd_synctable_obj.experiment,'path'),
					nsd_synctable_obj.writeobjectfile(nsd_synctable_obj.experiment.path);
				end
		end % add()

		function nsd_synctable_obj = remove(nsd_synctable_obj, arg2, arg3)
			% REMOVE - remove entry (entries) from an NSD_SYNCTABLE object
			%
			% This function has many forms:
			%
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, INDEX)
			%    or
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, CLOCK)
			%    or 
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, CLOCK1, CLOCK2)
			%    or 
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, DEVICE)
			%
			% In the first form, the table entry INDEX is removed.
			% In the second form, all table entries that include CLOCK
			%    are removed.
			% In the third form, all table entries that have CLOCK1 as clock1 and
			%    and CLOCK2 as clock2 are removed.
			% In the fourth form, all table entries that include the device
			% DEVICE are removed.
			%
			% The adjacency matrix is re-computed.
			%
				index = [];
				clock = [];
				device = [];
				clock2 = [];
				
				if isempty(arg2),
					return; % nothing to do
				elseif isint(arg2),
					index = arg2;
				elseif isa(arg2,'nsd_clock'),
					clock = arg2;
					if nargin>2,
						clock2 = arg3;
						if ~isa(clock2,'nsd_clock'),
							error(['The third argument must be of type NSD_CLOCK.']);
						end
					end
				elseif isa(arg2,'nsd_iodevice'),
					device = arg2;
				end

				N = numel(nsd_synctable_obj.entries);
				if ~isempty(index),
					nsd_synctable_obj.entries = nsd_synctable_obj.entries(setdiff(1:N,index));
					nsd_synctable_obj = computeadjacencymatrix(nsd_synctable_obj);
				elseif ~isempty(clock),
					if isempty(clock2),
						for i=1:N,
							if nsd_synctable_obj.entries(i).clock1==clock | ...
								nsd_synctable_obj.entries(i).clock2==clock,
								index(end+1) = i;
							end
						end
					else,
						for i=1:N,
							if nsd_synctable_obj.entries(i).clock1==clock & ...
								nsd_synctable_obj.entries(i).clock2==clock2,
								index(end+1) = i;
							end
						end
					end
					nsd_synctable_obj = nsd_synctable_obj.remove(index);
				elseif ~isempty(device),
					for i=1:N,
						if isa(nsd_synctable_obj.entries(i).clock1,'nsd_clock_iodevice'),
							if nsd_synctable_obj.entries(i).clock1.device==device,
								index(end+1) = i;
							end
						end
						if isa(nsd_synctable_obj.entries(i).clock2,'nsd_clock_iodevice'),
							if nsd_synctable_obj.entries(i).clock2.device==device,
								index(end+1) = i;
							end
						end
					end
					index = unique(index);
					nsd_synctable_obj = nsd_synctable_obj.remove(index);
				else,
					error(['Do not know how to handle second input of type ' class(arg2) '.']);
				end

				if isfield(nsd_synctable_obj.experiment,'path'),
					nsd_synctable_obj.writeobjectfile(nsd_synctable_obj.experiment.path);
				end
		end % remove()

		function nsd_synctable_obj = computeadjacencymatrix(nsd_synctable_obj)
			% COMPUTEGRAPH - (re)compute the adjacency matrix graph for an NSD_SYNCTABLE object
			%
			% NSD_SYNCTABLE_OBJ = COMPUTEADJACENCYMATRIX(NSD_SYNCTABLE_OBJ)
			%
			% (Re)compute the adjacency matrix property G from the table entries.
			%

				% Step 1:  Get all devices
				D = nsd_synctable_obj.load('name','(.*)');
				if ~iscell(D), D = {D}; end; % make sure we always have a cell
				
				% Step 2: Compute all overlaps across all pairs of devices and add them to the graph

				% Step 3:
				

		end % computeadjacencymatrix()

		function [timeref_out, message] = timeconvert(nsd_synctable_obj, timeref_in, second_referent, time_type)
			% TIMECONVERT - convert time between clocks
			%
			% [TIMEREF_OUT, MESSAGE] = TIMECONVERT(NSD_SYNCTABLE_OBJ, TIMEREF_IN, SECOND_REFERENT, TIME_TYPE)
			%
			% Given an NSD_TIMEREFERENCE object TIMEREF_IN, this function identifies the corresponding
			% values for an NSD_TIMEREFERENCE TIMEREF_OUT, which includes a time value 'time', a referent in
			% the form of an NSD_IODEVICE's clock (that underlies SECOND_REFERENT) and, possibly, 'epoch'. 
			% TIME_TYPE is the time type of TIMEREF_OUT. If not specified, it will be 'dev_local'.
			%
			% If the conversion cannot be made, TIMEREF_OUT will be empty and a message
			% will be written in MESSAGE.
			%
			% If necessary, the function uses the NSD_SYNCTABLE to make the conversion.
			%
			% See also: NSD_TIMEREFERENCE
			%
				timeref_out = [];
				message = '';
				if nargin < 4, time_type = 'dev_local'; end;

				  % Step 1: deal with trivial cases
				if timeref_in.referent == second_referent,
					% within referent
					if strcmpi(timeref_in.time_type,time_type),
						timeref_out = nsd_timereference(second_referent, time_type, timeref_in.epoch, timeref_in.time);
					else,
						error(['still need to implement within-referent conversion']);
						if isa(timeref_in,'nsd_iodevice'),
							timeref_out = timeconvert(timeref_in.referent, time_type);
						else,
							error(['do not know how to convert among non-devices.']);
						end
					end;
					return
				end

				second_clock = second_referent.underlying_clock(); % idea

				if strcmp(timeref_in.clock.type,'no_time') | strcmp(second_clock.type,'no_time'), % inherently unresolveable
					message = 'inherently unresolvable (at least one clock does not keep time)';
					return;
				end

				if strcmp(timeref_in.clock.type,'utc') & strcmp(second_clock.clock.type,'utc') | ...
						strcmp(timeref_in.clock.type,'exp_global_time') & strcmp(second_clock.type,'exp_global_time'),
					error(['do not know what to do...should I return exp_global_time or utc, or break it down into epochs?']);
					return;
				end

				  % Step 2: now deal with other combinations

				Gtable = nsd_synctable_obj.G;
				inf_indexes = isinf(Gtable);
				Gtable(inf_indexes) = 0;
				mygraph = digraph(Gtable);
				index1 = find(cellfun(@(x) eq(x,timeref_in.clock), nsd_synctable_obj.clocks));
				index2 = find(cellfun(@(x) eq(x,second_clock), nsd_synctable_obj.clocks));

				if isempty(index1) | isempty(index2),
					path = [];
				else,
					path = shortestpath(mygraph, index1, index2);
				end

				if ~isempty(path),
					timeref_here = timeref_in;
					for i=1:numel(path)-1,
						mystruct = nsd_synctable_obj.entries(nsd_synctable_obj.bestrule(path(i),path(i+1)));
						try, 
							[timeref_out] = directruleconversion(nsd_synctable_obj, ...
								timeref_here, mystruct, second_clock);
						catch,
							timeref_out = [];
							message = ['Error in evaluating directruleconversion: ' lasterr];
							return;
						end
						timeref_here = timeref_out;
					end
					return;
				end

				% if we are here, we didn't get it
				message = 'unable to find mapping between timeref_in and second_clock.';

		end % convert

		function [timeref_out]= directruleconversion(nsd_synctable_obj, timeref_in, rulestruct, second_clock)
			% DIRECTRULECONVERSION - Convert from one NSD_TIMEREFERENCE to another with a direct rule
			%
			% [TIMEREF_OUT] = DIRECTRULECONVERSION(NSD_SYNCTABLE_OBJ, TIMEREF_IN, RULESTRUCT, SECOND_CLOCK)
			%
			% Use the direct rule described in RULESTRUCT to convert between the NSD_TIMEREFERENCE
			% TIMEREF_IN and the second clock in SECOND_CLOCK.
			% 
			% See also: NSD_SYNCTABLE/ADD for a description of the RULESTRUCT parameters
			%
			%
				timeref_out = [];

				switch(rulestruct.rule),
					case 'equal',
						timeref_out = nsd_timereference(second_clock,timeref_in.epoch,timeref_in.time);
					otherwise,
						error(['I do not yet know how to implement the rule ' rulestruct.rule '.']);
				end
		end % directruleconversion() 

		function saveStruct = getsavestruct(nsd_synctable_obj)
			% GETSAVESTRUCT - Create a structure representation of the object that is free of handles
			%
			% SAVESTRUCT = GETSAVESTRUCT(NSD_SYNCTABLE_OBJ)
			%
			% Creates a structure representation of the NSD_SYNCTABLE_OBJ that is free of object handles
			%
			% SAVESTRUCT has the following properties:
			% Fieldname                 | Description
			% -------------------------------------------------------------------------------------
			% entries                   | 'entries' except with all clocks replaced with structures (see NSD_CLOCK_IODEVICE/CLOCK2STRUCT)
			% G                         | G numeric array as is
			% bestrule                  | bestrule array as is
			% clocks                    | NSD_CLOCK_IODEVICE entries replaced with structures (see NSD_CLOCK_IODEVICE/CLOCK2STRUCT)
			% objectfilename            | The object file name string as is

				saveStruct.entries        = nsd_synctable_obj.entries;
				saveStruct.G              = nsd_synctable_obj.G;
				saveStruct.bestrule       = nsd_synctable_obj.bestrule;
				saveStruct.clocks         = nsd_synctable_obj.clocks;
				saveStruct.objectfilename = nsd_synctable_obj.objectfilename;

				if isa(nsd_synctable_obj.experiment,'nsd_experiment'),
					saveStruct.experiment = nsd_synctable_obj.experiment.reference; % though this will be replaced, it might help in debugging
				end

				for i=1:numel(saveStruct.clocks),
					saveStruct.clocks{i} = saveStruct.clocks{i}.clock2struct;
				end

				for i=1:numel(saveStruct.entries),
					saveStruct.entries(i).clock1 = saveStruct.entries(i).clock1.clock2struct;
					saveStruct.entries(i).clock2 = saveStruct.entries(i).clock2.clock2struct;
				end

		end % getsavestruct()

	end % methods

end % nsd_synctable class

 % rule example: 
 %   'isequal' % they are the same, no parameters
 %   'commontriggers' % they acquire a common trigger
 %      parameters: dev1channel:'dev1:m1', dev2channel: 'dev2:d3'
 


%ok, there are some implicit conversions:
%
%if our device uses 'utc', 'exp_global_time', or 'dev_global_time', as its primary clock, then we can always convert to 'dev_local_time' or vice-versa
%
%
