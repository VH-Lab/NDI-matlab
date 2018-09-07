classdef nsd_clocktype
% NSD_CLOCKTYPE - a class for specifying a clock type in the NSD framework
%
%
	properties (SetAccess=protected, GetAccess=public)
		type % the nsd_clock type; in this class, acceptable values are 'UTC', 'exp_global_time', and 'no_time'
	end

	methods
		function obj = nsd_clocktype(type)
			% NSD_CLOCKTYPE - Creates a new NSD_CLOCKTYPE object
			%
			% OBJ = NSD_CLOCKTYPE(TYPE)
			%
			% Creates a new NSD_CLOCKTYPE object. TYPE can be
			% any of the following strings (with description):
			%
			% TYPE string               | Description
			% ------------------------------------------------------------------------------
			% 'utc'                     | Universal coordinated time (within 0.1ms)
			% 'approx_utc'              | Universal coordinated time (within 5 seconds)
			% 'exp_global_time'         | Experiment global time (within 0.1ms)
			% 'approx_exp_global_time'  | Experiment global time (within 5s)
			% 'dev_global_time'         | A device keeps its own global time (within 0.1ms) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'approx_dev_global_time'  |  A device keeps its own global time (within 5 s) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'dev_local_time'          | A device keeps its own local time only within epochs
			% 'no_time'                 | No timing information
			% 'inherited'               | The timing information is inherited from another device.
			%
				obj.type = '';

				if nargin>0,
					obj = setclocktype(obj,type);
				end
		end % nsd_clock()
		
		function nsd_clocktype_obj = setclocktype(nsd_clocktype_obj, type)
			% SETCLOCKTYPE - Set the type of an NSD_CLOCKTYPE
			%
			% NSD_CLOCKTYPE_OBJ = SETCLOCKTYPE(NSD_CLOCKTYPE_OBJ, TYPE)
			%
			% Sets the TYPE property of an NSD_CLOCKTYPE object NSD_CLOCKTYPE_OBJ.
			% Valid values for the TYPE string are as follows:
			%
			% TYPE string               | Description
			% ------------------------------------------------------------------------------
			% 'utc'                     | Universal coordinated time (within 0.1ms)
			% 'approx_utc'              | Universal coordinated time (within 5 seconds)
			% 'exp_global_time'         | Experiment global time (within 0.1ms)
			% 'approx_exp_global_time'  | Experiment global time (within 5s)
			% 'dev_global_time'         | A device keeps its own global time (within 0.1ms) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'approx_dev_global_time'  |  A device keeps its own global time (within 5 s) 
			%                           |   (that is, it knows its own clock across recording epochs)
			% 'dev_local_time'          | A device keeps its own local time only within epochs
			% 'no_time'                 | No timing information
			% 'inherited'               | The timing information is inherited from another device.
			%
			%
				if ~ischar(type),
					error(['TYPE must be a character string.']);
				end

				type = lower(type);

				switch type,
					case {'utc','approx_utc','exp_global_time','approx_exp_global_time',...
						'dev_global_time', 'approx_dev_global_time', 'dev_local_time', ...
						'no_time','inherited'},
						% no error
					otherwise,
						error(['Unknown clock type ' type '.']);
				end

				nsd_clocktype_obj.type = type;
		end % setclocktype() %

		function [cost, mapping] = epochgraph_edge(nsd_clocktype_a, nsd_clocktype_b)
			% EPOCHGRAPH_EDGE - provide epochgraph edge based purely on clock type
			%
			% [COST, MAPPING] = EPOCHGRAPH_EDGE(NSD_CLOCKTYPE_A, NSD_CLOCKTYPE_B)
			%
			% Returns the COST and NSD_TIMEMAPPING object MAPPING that describes the
			% automatic mapping between epochs that have clock types NSD_CLOCKTYPE_A
			% and NSD_CLOCKTYPE_B.
			%
                        % The following NSD_CLOCKTYPES, if they exist, are linked across epochs with
                        % a cost of 1 and a linear mapping rule with shift 1 and offset 0:
                        %   'utc' -> 'utc'
                        %   'utc' -> 'approx_utc'
                        %   'exp_global_time' -> 'exp_global_time'
                        %   'exp_global_time' -> 'approx_exp_global_time'
                        %   'dev_global_time' -> 'dev_global_time'
                        %   'dev_global_time' -> 'approx_dev_global_time'
			%
			% Otherwise, COST is Inf and MAPPING is empty.

				cost = Inf;
				mapping = [];

				if strcmp(nsd_clocktype_a.type,'no_time') | strcmp(nsd_clocktype_b.type,'no_time'), 
					% stop the search if its trivial
					return;
				end
		
				from_list = {'utc','utc','exp_global_time','exp_global_time','dev_global_time','dev_global_time'};
				to_list = {'utc','approx_utc','exp_global_time','approx_exp_global_time',...
					'dev_global_time','approx_dev_global_time'};

				index = find(  strcmp(nsd_clocktype_a.type,from_list) & strcmp(nsd_clocktype_b.type,to_list) );
				if ~isempty(index),
					cost = 1;
					mapping = nsd_timemapping([1 0]); % trivial mapping
				end
		end  % epochgraph_edge

		function b = needsepoch(nsd_clocktype_obj)
			% NEEDSEPOCH - does this clocktype need an epoch for full description?
			%
			% B = NEEDSEPOCH(NSD_CLOCKTYPE_OBJ)
			%
			% Does this NSD_CLOCKTYPE object need an epoch in order to specify time?
			%
			% Returns 1 for 'dev_local_time', 0 otherwise.
			%
				b = strcmp(nsd_clocktype_obj,'dev_local_time');
		end % needsepoch

		function b = eq(nsd_clocktype_obj_a, nsd_clocktype_obj_b)
			% EQ - are two NSD_CLOCKTYPE objects equal?
			%
			% B = EQ(NDS_CLOCK_OBJ_A, NSD_CLOCKTYPE_OBJ_B)
			%
			% Compares two NSD_CLOCKTYPE_objects and returns 1 if they refer to the 
			% same clock type.
			%
			b = strcmp(nsd_clocktype_obj_a.type,nsd_clocktype_obj_b.type);
		end % eq()

		function b = ne(nsd_clocktype_obj_a, nsd_cock_obj_b)
			% NE - are two NSD_CLOCKTYPE objects not equal?
			%
			% B = EQ(NDS_CLOCK_OBJ_A, NSD_CLOCKTYPE_OBJ_B)
			%
			% Compares two NSD_CLOCKTYPE_objects and returns 0 if they refer to the 
			% same clock type.
			%
			b = ~eq(nsd_clocktype_obj_a.type,nsd_clocktype_obj_b.type);
		end % ne()

	end % methods
end % nsd_clocktype class


