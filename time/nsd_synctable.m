classdef nsd_synctable < nsd_base
% NSD_SYNCTABLE - A class for managing synchronization across NSD_CLOCK objects
%

	properties (SetAccess=protected,GetAccess=public),
		entries % entries of the NSD_SYNCTABLE
		G  % adjacency matrix of clocks for construction of a graph
		bestrule % table entry of the best rule between two clocks
		clocks % a cell array of nsd_clock_iodevice 
	end % properties
	properties (SetAccess=protected,GetAccess=protected)
	end % properties
	methods
		function obj = nsd_synctable(varargin)
			% NSD_SYNCTABLE - Creates a new NSD_SYNCTABLE object
			%
			% OBJ = NSD_SYNCTABLE()
			%
			% Creates an empty NSD_SYNCTABLE object.
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
			if nargin==2,
				if strcmp(lower(varargin{2}),lower('OpenFile')),
					obj = obj.readobjectfile(varargin{1});
				end
			elseif nargin==3,
				if strcmp(lower(varargin{2}),lower('OpenFileAndUpdate')),
					obj = obj.readobjectfile(varargin{1});
					obj = obj.UpdateHandles(varargin{3});
				end
			end
		end % nsd_synctable()
			
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
		end % remove()

		function nsd_synctable_obj = computeadjacencymatrix(nsd_synctable_obj)
			% COMPUTEGRAPH - (re)compute the adjacency matrix graph for an NSD_SYNCTABLE object
			%
			% NSD_SYNCTABLE_OBJ = COMPUTEADJACENCYMATRIX(NSD_SYNCTABLE_OBJ)
			%
			% (Re)compute the adjacency matrix property G from the table entries.
			%
				% Step 1: make sure the nsd_synctable_obj.clocks cell array does not have duplicate entries
				clock1s = {nsd_synctable_obj.entries.clock1};
				clock2s = {nsd_synctable_obj.entries.clock2};
				clocklist = cat(2,clock1s,clock2s);
				extra_indexes = [];
				for i=1:numel(clocklist),
					tf= cellfun(@(x) eq(x, clocklist{i}), clocklist);
					tf(1:i) = 0; % duh, it equals itself; also, only flag later repeats
					if any(tf),
						extra_indexes = cat(2,extra_indexes,find(tf));
					end
				end
				nsd_synctable_obj.clocks = clocklist(setdiff(1:numel(clocklist),extra_indexes));

				% Step 2: now make the graph table
				N = numel(nsd_synctable_obj.clocks);
				nsd_synctable_obj.G = Inf(N,N);
				nsd_synctable_obj.bestrule = nan(N,N);

				% Add the entries to G

				for i=1:N, % compute G(i,:) 
					% where in entries is the ith clock the first clock?
					entry_locations = find(cellfun(@(x) eq(x,nsd_synctable_obj.clocks{i}), clock1s));
					for j=1:numel(entry_locations),
						clock2 = nsd_synctable_obj.entries(entry_locations(j)).clock2;
						% which nsd_synctable_obj.clocks entry number is clock2?
						index2 = find(cellfun(@(x) eq(x,clock2), nsd_synctable_obj.clocks));

						if ~isempty(index2),
							% now we know the G(i,index2) is where the weight should be 

							% test to see if we should replace the weight
							if nsd_synctable_obj.G(i,index2) > nsd_synctable_obj.entries(entry_locations(j)).cost,
								nsd_synctable_obj.G(i,index2) = nsd_synctable_obj.entries(entry_locations(j)).cost;
								nsd_synctable_obj.bestrule(i,index2) = entry_locations(j);
							end

							% now handle special implicit cases

							switch nsd_synctable_obj.entries(entry_locations(j)).rule,
								case 'equal', % goes in both directions

									if nsd_synctable_obj.G(index2,i) > nsd_synctable_obj.entries(entry_locations(j)).cost,
										nsd_synctable_obj.G(index2,i) = nsd_synctable_obj.entries(entry_locations(j)).cost;
										nsd_synctable_obj.bestrule(index2,i) = entry_locations(j);
									end

								otherwise,
									% do nothing

							end
							
						end
					end
				end

		end % computeadjacencymatrix()

		function epoch = epoch_overlap(nsd_synctable_obj, clock, epoch, t0, t1)

		end % epoch_overlap()

		function [timeref_out, message] = timeconvert(nsd_synctable_obj, timeref_in, second_clock)
			% TIMECONVERT - convert time between clocks
			%
			% [TIMEREF_OUT, MESSAGE] = TIMECONVERT(NSD_SYNCTABLE_OBJ, TIMEREF_IN, SECOND_CLOCK)
			%
			% Given an NSD_TIMEREFERENCE object TIMEREF_IN, this function identifies the corresponding
			% values for TIMEREF_OUT, which includes a time value 'time', a clock (SECOND_CLOCK), and,
			% possibly, 'epoch'.
			%
			% If the conversion cannot be made, TIMEREF_OUT will be empty and a message
			% will be written in MESSAGE.
			%
			% If necessary, the function uses the NSD_SYNCTABLE to make the conversion.
			%
				timeref_out = [];
				message = '';

				  % Step 1: deal with trivial cases
				if timeref_in.clock==second_clock,
					timeref_out = nsd_timereference(second_clock, timeref_in.epoch, timeref_in.time);
					return
				end

				if strcmp(timeref_in.clock.type,'no_time') | strcmp(second_clock.type,'no_time'), % inherently unresolveable
					message = 'inherently unresolvable (at least one clock does not keep time)';
					return;
				end

				if strcmp(timeref_in.type,'utc') & strcmp(second_clock.type,'utc') | ...
						strcmp(timeref_in.type,'exp_global_time') & strcmp(second_clock.type,'exp_global_time'),
					return;
				end

				  % Step 2: now deal with other combinations

				Gtable = nsd_synctable_obj.G;
				inf_indexes = isinf(Gtable);
				Gtable(inf_indexes) = 0;
				mygraph = digraph(Gtable);
				index1 = find(cellfun(@(x) eq(x,timeref_in.clock), nsd_synctable_obj.clocks));
				index2 = find(cellfun(@(x) eq(x,second_clock), nsd_synctable_obj.clocks));
				path = shortestpath(mygraph, index1, index2);

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

				for i=1:numel(saveStruct.clocks),
					saveStruct.clocks{i} = saveStruct.clocks{i}.clock2struct;
				end

				for i=1:numel(saveStruct.entries),
					saveStruct.entries(i).clock1 = saveStruct.entries(i).clock1.clock2struct;
					saveStruct.entries(i).clock2 = saveStruct.entries(i).clock2.clock2struct;
				end

		end % getsavestruct()

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
			end

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

		function nsd_synctable_obj = updatehandles(nsd_synctable_obj, exp)
			% UPDATEHANDLES - Update CLOCK and IODEVICE handles with those from an experiment
			%
			% NSD_SYNCTABLE_OBJ = UPDATEHANDLES(NSD_SYNCTABLE_OBJ, EXP)
			%
			% Using the IODEVICE information in the NSD_EXPERIMENT object EXP,
			% this function updates the handles of the NSD_SYNCTABLE_OBJECT NSD_SYNCTABLE_OBJ.
			%
			% This function is necessary because handles cannot be updated and linked to
			% an NSD_EXPERIMENT object from a file.
			%
			% If the clocks of NSD_SYNCTABLE_OBJ are already handles, they are not updated.
			%
				% Step 1: pull all devices
				d = exp.iodevice_load('name','(.*)');
				for i=1:numel(d),
					for j=1:numel(nsd_synctable_obj.clocks),
						if isstruct(nsd_synctable_obj.clocks{j}),
							if isclockstruct(d{i}.clock, nsd_synctable_obj.clocks{j}),
								nsd_synctable_obj.clocks{j} = d{i}.clock;
							end
						end
					end
					for j=1:numel(nsd_synctable_obj.entries),
						if isstruct(nsd_synctable_obj.entries(j).clock1),
							if isclockstruct(d{i}.clock, nsd_synctable_obj.entries(j).clock1),
								nsd_synctable_obj.entries(j).clock1 = d{i}.clock;
							end
						end

						if isstruct(nsd_synctable_obj.entries(j).clock2),
							if isclockstruct(d{i}.clock, nsd_synctable_obj.entries(j).clock2),
								nsd_synctable_obj.entries(j).clock2 = d{i}.clock;
							end
						end
					end
				end
		end % updatehandles

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
