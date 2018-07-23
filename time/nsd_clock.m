classdef nsd_clock 
% NSD_CLOCK - a class for specifying time in the NSD framework
%
%
	properties (SetAccess=protected, GetAccess=public)
		type % the nsd_clock type; in this class, acceptable values are 'UTC', 'exp_global_time', and 'no_time'
	end

	methods
		function obj = nsd_clock(type)
			% NSD_CLOCK - Creates a new NSD_CLOCK object
			%
			% OBJ = NSD_CLOCK(TYPE)
			%
			% Creates a new NSD_CLOCK object. TYPE can be
			% any of the following strings (with description):
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The iodevice keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The iodevice keeps experiment global time (within 0.1ms)
			% 'no_time'          | The iodevice has no timing information
			%
				obj.type = '';

				if nargin>0,
					obj = setclocktype(obj,type);
				end
		end % nsd_clock()
		
		function nsd_clock_obj = setclocktype(nsd_clock_obj, type)
			% SETCLOCKTYPE - Set the type of an NSD_CLOCK
			%
			% NSD_CLOCK_OBJ = SETCLOCKTYPE(NSD_CLOCK_OBJ, TYPE)
			%
			% Sets the TYPE property of an NSD_CLOCK object NSD_CLOCK_OBJ.
			% Valid values for the TYPE string are as follows:
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The iodevice keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The iodevice keeps experiment global time (within 0.1ms)
			% 'dev_global_time'  | The iodevice keeps its own global time (within 0.1ms) 
			%                    |   (that is, it knows its own clock across recording epochs)
			% 'dev_local_time'   | The iodevice keeps its own local time only within epochs
			% 'no_time'          | The iodevice has no timing information
			%
			%
				if ~ischar(type),
					error(['TYPE must be a character string.']);
				end

				type = lower(type);

				switch type,
					case {'utc','exp_global_time','dev_global_time', 'dev_local_time', 'no_time'},
						% no error
					otherwise,
						error(['Unknown clock type ' type '.']);
				end

				nsd_clock_obj.type = type;
		end % setclocktype() %

		function b = eq(nsd_clock_obj_a, nsd_clock_obj_b)
			% EQ - are two NSD_CLOCK objects equal?
			%
			% B = EQ(NDS_CLOCK_OBJ_A, NSD_CLOCK_OBJ_B)
			%
			% Compares two NSD_CLOCK_objects and returns 1 if they refer to the 
			% same clock type.
			%
			b = strcmp(nsd_clock_obj_a.type,nsd_clock_obj_b.type);
		end % eq()

		function b = ne(nsd_clock_obj_a, nsd_cock_obj_b)
			% NE - are two NSD_CLOCK objects not equal?
			%
			% B = EQ(NDS_CLOCK_OBJ_A, NSD_CLOCK_OBJ_B)
			%
			% Compares two NSD_CLOCK_objects and returns 0 if they refer to the 
			% same clock type.
			%
			b = ~eq(nsd_clock_obj_a.type,nsd_clock_obj_b.type);
		end % ne()

	end % methods
end % nsd_clock class


