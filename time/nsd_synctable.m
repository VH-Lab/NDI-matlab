classdef nsd_synctable < nsd_base

	NOTE ONLY IN MY IMAGINATION RIGHT NOW

	% NSD_SYNCTABLE - A class for managing synchronization across NSD_CLOCK objects
	%

	properties (SetAccess=protected,GetAccess=public),
		entries % entries of the NSD_SYNCTABLE
		G  % adjacency matrix of clocks for construction of a graph
	end % properties
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
		end % nsd_synctable()
			
		function nsd_synctable_obj = add(nsd_synctable_obj, clock1, clock2, rule, ruleparameters, cost, valid_range)
			% ADD - add a time conversion rule entry to an NSD_SYNCTABLE object
			%
			% NSD_SYNCTABLE_OBJ = ADD(NSD_SYNCTABLE_OBJ, CLOCK1, CLOCK2, ...
			%     RULE, RULEPARAMETERS, COST, VALID_RANGE) 
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
				% EDIT HERE NEXT TIME		

				nsd_synctable_obj = computegraph(nsd_synctable_obj);

		end % add()

		function nsd_synctable_obj = remove(nsd_synctable_obj, arg2)
			% REMOVE - remove entry (entries) from an NSD_SYNCTABLE object
			%
			% This function has many forms:
			%
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, INDEX)
			%    or
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, CLOCK)
			%    or 
			% NSD_SYNCTABLE_OBJ = REMOVE(NSD_SYNCTABLE_OBJ, DEVICE)
			%
			% In the first form, the table entry INDEX is removed.
			% In the second form, all table entries that include CLOCK
			% are removed.
			% In the third form, all table entries that include the device
			% DEVICE are removed.
			%
			% The adjacency matrix is re-computed.
			%
				index = [];
				clock = [];
				device = [];
				
				if isint(arg2),
					index = arg2;
				elseif isa(arg2,'nsd_clock'),
					clock = arg2;
				elseif isa(arg2,'nsd_device'),
					device = arg2;
				end

				N = numel(nsd_syntable_obj.entries);
				if ~isempty(index),
					nsd_synctable_obj.entries = nsd_synctable_obj.entries(setdiff(1:N,index));
					nsd_synctable_obj = computegraph(nsd_synctable_obj);
				elseif ~isempty(clock),
					for i=1:N,
						if nsd_synctable_obj.entries(i).clock1==clock | ...
							nsd_synctable_obj.entries(i).clock2==clock,
							index(end+1) = i;
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

		function nsd_synctable_obj = computegraph(nsd_synctable_obj)
			% COMPUTEGRAPH - (re)compute the adjacency matrix graph for an NSD_SYNCTABLE object
			%
			% NSD_SYNCTABLE_OBJ = COMPUTEGRAPH(NSD_SYNCTABLE_OBJ)
			%
			% (Re)compute the adjacency matrix property G from the table entries.
			%



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

				if source_clock==second_clock,
					t_prime = source_t;
					epochnumber_prime = source_epoch;
					return
				end
				
				% now have to deal with many possibilites
				if strcmp(source_clock.type,'utc'),
					if strcmp(second_clock.type,'utc'),
						t_prime = source_t;
						epochnumber_prime = source_epoch;
						return
					end

					if strcmp(second_clock.type,'exp_global_time')
						error(['Do not know what to do yet.']);
						return
					end

					if isa(second_clock,'nsd_clock_device'),
						% need to use a rule
						
					end

				end

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
