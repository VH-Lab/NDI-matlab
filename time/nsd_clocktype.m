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

		function nsd_clock_struct = clock2struct(nsd_clocktype_obj)
			% CLOCK2STRUCT - create a structure version of the clock that lacks handles
			%
			% NSD_CLOCKTYPE_STRUCT = CLOCK2STRUCT(NSD_CLOCKTYPE_OBJ)
			%
			% Return a structure with information that specifies an NSD_CLOCKTYPE_OBJ
			% within an NSD_EXPERIMENT but does not contain handles.
			%
			% This function is useful for saving a clock to disk.
			%
			% NSD_CLOCKTYPE_STRUCT contains the following fields:
			% Fieldname              | Description
			% --------------------------------------------------------------------------
			% 'type'                 | The 'type' field of NSD_CLOCKTYPE_IODEVICE_OBJ
			%
				nsd_clock_struct.type = nsd_clocktype_obj.type;
		end % clock2struct()

		function b = isclockstruct(nsd_clocktype_obj, nsd_clock_struct)
			% ISCLOCKSTRUCT - is an nsd_clock_struct description equivalent to this clock?
			%
			% B = ISCLOCKSTRUCT(NSD_CLOCKTYPE_OBJ, NSD_CLOCKTYPESTRUCT)
			%
			% Returns 1 if NSD_CLOCKTYPE_STRUCT is an equivalent description to NSD_CLOCKTYPE_OBJ
			% 
			% In the base class, only the property/field 'type' is examined.
			%
				b = 0;
				if isfield(nsd_clock_struct,'type'),
					b = strcmp(nsd_clocktype_obj.type, nsd_clock_struct.type);
				end
		end % isclockstruct
		
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


