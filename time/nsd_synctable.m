classdef nsd_synctable < nsd_base

	NOTE ONLY IN MY IMAGINATION RIGHT NOW

	% NSD_SYNCTABLE - A class for managing synchronization across NSD_CLOCK objects
	%

	properties (SetAccess=protected,GetAccess=public),
		entries % entries of the NSD_SYNCTABLE
		G  % adjacency matrix of clocks for construction of a graph
		bestrule % table entry of the best rule between two clocks
		clocks % a cell array of nsd_clock types 
	end % properties
	properties (SetAccess=protected,GetAccess=protected)
		recursion_count % how many times have we recursively called nsd_synctable.synctable?
	methods
		function obj = nsd_synctable
			% NSD_SYNCTABLE - Creates a new NSD_SYNCTABLE object
			%
			% OBJ = NSD_SYNCTABLE()
			%
			% Creates an empty NSD_SYNCTABLE object.
			%
			obj=obj@nsd_base;
			obj.entries = emptystruct('clock1','clock2','rule','ruleparameters','cost','valid_range');
			obj.G = [];
			obj.clocks = {};
			
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
			%                   |   clock1_channels: nsd_device_string (e.g., 'mydev:mk1')
			%                   |   clock2_channels: nsd_device_string (e.g., 'myotherdev:din1')
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
			% Whenever a new NSD_CLOCK CLOCK1 or CLOCK2 is added to the tabe, and if those clocks
			% are of type 'utc', 'exp_global_time', or 'dev_global_time', and are associated with a
			% device, then additional entries are added that chart the implict 'withindevice' conversions.
			%
				if isstruct(clock1),
					mystruct = clock1;
				else,
					mystruct = var2struct('clock1','clock2','rule','ruleparameters','cost','valid_range');
				end

				% don't remove existing entries; might be more than one sync mechanism between two identical sources

				%index1 = cellfun(@(x) @eq(x,clock1), nsd_synctable_obj.clocks);
				%index2 = cellfun(@(x) @eq(x,clock2), nsd_synctable_obj.clocks);
				%if isempty(find(index1)),
				%	nsd_synctable_obj.clocks{end+1} = clock1;
				%	nsd_synctable_obj.clocks{end+1} = clock2;
				%end

				nsd_synctable_obj.entries(end+1) = mystruct;
				nsd_synctable_obj = nsd_synctable_obj.addimplicittableentries(clock1);
				nsd_synctable_obj = nsd_synctable_obj.addimplicittableentries(clock2);
				nsd_synctable_obj = computegraph(nsd_synctable_obj);
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
				elseif isa(arg2,'nsd_device'),
					device = arg2;
				end

				N = numel(nsd_syntable_obj.entries);
				if ~isempty(index),
					nsd_synctable_obj.entries = nsd_synctable_obj.entries(setdiff(1:N,index));
					nsd_synctable_obj = computegraph(nsd_synctable_obj);
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
						if isa(nsd_synctable_obj.entries(i).clock1,'nsd_clock_device'),
							if nsd_synctable_obj.entries(i).clock1.device==device),
								index(end+1) = i;
							end
						end
						if isa(nsd_synctable_obj.entries(i).clock2,'nsd_clock_device'),
							if nsd_synctable_obj.entries(i).clock2.device==device),
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

		function nsd_synctable_obj = addimplicittableentries(nsd_synctable_obj, clock)
			% ADDIMPLICITTABLEENTRIES - Add 'implicit' conversions among a clock and other clocks associated with itself
			%
			% NSD_SYNCTABLE_OBJ = ADDIMPLICITTABLEENTRIES(NSD_SYNCTABLE_OBJ, CLOCK)
			%
			% Adds all implicit conversions among a CLOCK (type:NSD_CLOCK)  to the
			% NSD_SYNCTABLE_OBJECT NSD_SYNCTABLE_OBJ. For example, if an NSD_CLOCK_DEVICE
			% has 'utc' as its type, it can convert to 'dev_local_time' or vice-versa. These
			% implicit conversions will be added to the table.
			%
				if ~isa(clock,'nsd_clock'),
					error(['CLOCK must be an object of type NSD_CLOCK.']);
				end

				clock1s = {nsd_synctable_obj.entries.clock1};
				table_locations = find(cellfun(@(x) @eq(x,clock), clock1s));

				switch clock.type,
					case {'utc','exp_global_time','dev_global_time'},
						if isa(clock,'nsd_clock_device'),
							clock2 = nsd_clock_device('dev_local_time', clock.device); % might not catch all cases
							% check to make sure it is not already there
							mystruct.clock1 = clock;
							mystruct.clock2 = clock2;
							mystruct.rule = 'within';
							mystruct.ruleparameters = [];
							mystruct.cost = 3;
							mystuct.valid_range = [];

							alreadythere = 0;
							for j=1:numel(table_locations),
								if clock2==nsd_synctable_obj.entries(table_locations(j).clock2)
									if eqlen(mystruct,table_locations(j)),
										alreadythere = 1;
										break;
									end
								end
							end
							if ~alreadythere,
								nsd_synctable_obj.entries(end+1) = mystruct;
							end
						end
				end

		end % addimplicittableentries

		function nsd_synctable_obj = computegraph(nsd_synctable_obj)
			% COMPUTEGRAPH - (re)compute the adjacency matrix graph for an NSD_SYNCTABLE object
			%
			% NSD_SYNCTABLE_OBJ = COMPUTEGRAPH(NSD_SYNCTABLE_OBJ)
			%
			% (Re)compute the adjacency matrix property G from the table entries.
			%
			
				clock1s = {nsd_synctable_obj.entries.clock1};
				clock2s = {nsd_synctable_obj.entries.clock2};
				nsd_synctable_obj.clocks = unique(cat(2,clock1s,clock2s));
				N = numel(nsd_synctable_obj.clocks);
				nsd_synctable_obj.G = zeros(N,N);
				nsd_synctable_obj.bestrule = nan(N,N);

				for i=1:N,
					% where is the ith clock the first clock?
					table_locations = find(cellfun(@(x) @eq(x,nsd_syncable_obj.clocks{i}), clock1s));
					for j=1:numel(table_locations),
						clock2 = nsd_synctable_obj.entries(locations(j).clock2);
						% which nsd_synctable_obj.clocks entry number is clock2?
						index2 = find(cellfun(@(x) @eq(x,nsd_syncable_obj.clocks{i}), clock2));

						% now we know the G(i,index2) is where the weight should be 
						% test to see if we should replace the weight
						if nsd_synctable_obj.G(i,index2) == 0 | ...
							nsd-synctable_obj.G(i,index2) > nsd_synctable_obj.entries(locations(j).cost),
							nsd_synctable_obj.G(i,index2) = nsd_synctable_obj.entries(locations(j).cost);
							nsd_synctable_obj.bestrule(i,index2) = locations(j);
						end
					end
				end

		end % computegraph()

		function epoch = epoch_overlap(nsd_synctable_obj, clock, epoch, t0, t1)

		end % epoch_overlap()

		function [t_prime, epochnumber_prime] = timeconvert(nsd_synctable_obj, source_clock, source_t, source_epoch, second_clock)
			% TIMECONVERT - convert time between clocks
			%
			% [T_PRIME, EPOCHNUMBER_PRIME] = TIMECONVERT(NSD_SYNCTABLE_OBJ, ...
			%       SOURCE_CLOCK, SOURCE_T, SOURCE_EPOCH, SECOND_CLOCK)
			%
			% Given a source clock SOURCE_CLOCK (type: NSD_CLOCK) and a source time SOURCE_T,
			% and possibly a SOURCE_EPOCH, this function identifies the corresponding time T_PRIME
			% (and possibly the epoch EPOCHNUMBER_PRIME) on a SECOND_CLOCK (type: NSD_CLOCK).
			%
			% If necessary, the function uses the NSD_SYNCTABLE to make the conversion.
			%
				t_prime = [];
				epochnumber_prime = [];

				  % Step 1: if we are stuck, bail out
				if nsd_synctable_obj.recusion_count > 2, % can't find any mapping
					nsd_synctable_obj.recursion_count = 0;
					return;
				end

				  % Step 2: deal with trivial cases
				if source_clock==second_clock,
					t_prime = source_t;
					epochnumber_prime = source_epoch;
					nsd_synctable_obj.recursion_count = 0; 
					return
				end

				if strcmp(source_clock.type,'no_time') | strcmp(second_clock.type,'no_time'), % inherently unresolveable
					nsd_synctable_obj.recursion_count = 0;
					return;
				end

				if strcmp(source_clock.type,'utc') & strcmp(second_clock.type,'utc') | ,
						strcmp(source_clock.type,'exp_global_time') & strcmp(second_clock.type,'exp_global_time'),
					t_prime = source_t;
					epochnumber_prime = source_epoch;
					nsd_synctable_obj.recursion_count = 0; 
					return;
				end

				if isa(source_clock,'nsd_clock_device') & isa(second_clock,'nsd_clock_device'),
					if strcmp(source_clock.type,'dev_global_time') & strcmp(second_clock.type,'dev_global_time') & ...
							(source_clock.device==second_clock.device),
						t_prime = source_t;
						epochnumber_prime = source_epoch;
						nsd_synctable_obj.recursion_count = 0; 
						return;
					end
				end

				  % Step 3: now deal with other combinations

				mygraph = digraph(G);
				index1 = cellfun(@(x) @eq(x,source_clock), nsd_synctable_obj.clocks);
				index2 = cellfun(@(x) @eq(x,second_clock), nsd_synctable_obj.clocks);
				path = shortestpath(mygraph, index1, index2);

				if ~isempty(path),
					t_prime = source_t;
					epochnumber_prime = source_epoch;
					for i=1:numel(path)-1,
						mystruct = nsd_synctable_objs.entries(nsd_synctable_objs.bestrule(path(i),path(i+1)));
						[t_prime,epochnumber_prime] = directruleconversion(nsd_synctable_obj, ...
							mystruct.source_clock, t_prime, epoch_numberprime, mystruct.second_clock, ...
							mystruct.rule, mystruct.ruleparameters, mystruct.valid_range);
					end
					nsd_synctable_obj.recursion_count = 0; 
					return;
				end

				% okay, now we are down to 'dev_local' clocks and we need to know if epochs on different devices overlap 
				% 


		end % convert

		function [t_prime, epochnumber_prime] = directruleconversion(nsd_synctable_obj, source_clock, source_t, source_epoch, second_clock, rule, ruleparameters, valid_range)
			%
			%
		end

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
%If our device uses 'no_time', then it's hopeless
%
%
