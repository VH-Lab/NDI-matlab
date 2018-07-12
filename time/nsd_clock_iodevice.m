classdef nsd_clock_iodevice < nsd_clock
% NSD_CLOCK_IODEVICE - a class for specifying time in the NSD framework for clocks that are linked to NSD_IODEVICE objects
%
%
	properties (SetAccess=protected, GetAccess=public)
		iodevice % the nsd_iodevice object associated with the clock
	end

	methods
		function obj = nsd_clock_iodevice(type, iodevice)
			% NSD_CLOCK_IODEVICE - Creates a new NSD_CLOCK_DEVICE object, an NSD_CLOCK associated with a device
			%
			% OBJ = NSD_CLOCK_IODEVICE(TYPE, IODEVICE)
			%
			% Creates a new NSD_CLOCK object for the device DEVICE. TYPE can be
			% any of the following strings (with description):
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
                        % 'utc'              | The device keeps universal coordinated time (within 0.1ms)
                        % 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
                        % 'no_time'          | The device has no timing information
			% 'dev_global_time'  | The device has a global clock for itself
			% 'dev_local_time'   | The device only has local time, within a recording epoch
			%
				obj = obj@nsd_clock();

				obj.type = '';
				obj.iodevice = [];

				if ~isa(iodevice,'nsd_iodevice') & ~isempty(iodevice),
					error(['DEVICE must be of type NSD_IODEVICE.']);
				else,
					obj.iodevice = iodevice;
				end
				if nargin>0,
					obj = setclocktype(obj,type);
				end

		end % nsd_clock_iodevice()
		
		function nsd_clock_iodevice_obj = setclocktype(nsd_clock_iodevice_obj, type)
			% SETCLOCKTYPE - Set the type of an NSD_CLOCK_IODEVICE
			%
			% NSD_CLOCK_IODEVICE_OBJ = SETCLOCKTYPE(NSD_CLOCK_IODEVICE_OBJ, TYPE)
			%
			% Sets the TYPE property of an NSD_CLOCK_IODEVICE object NSD_CLOCK_IODEVICE_OBJ.
			% Valid values for the TYPE string are as follows:
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The device keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
			% 'dev_global_time'  | The device has a global clock for itself
			% 'dev_local_time'   | The device only has local time, within a recording epoch
			% 'no_time'          | The device has no timing information
			%
				if ~ischar(type),
					error(['TYPE must be a character string.']);
				end

				try,
					nsd_clock_iodevice_obj = setclocktype@nsd_clock_iodevice_obj(nsd_clock_device_obj,type);
				catch,
					type = lower(type);
					switch type,
						case {'dev_global_time','dev_local_time'},
							% no error
						otherwise,
							error(['Unknown clock type ' type '.']);
					end
					nsd_clock_iodevice_obj.type = type;
				end
		end % setclocktype() %

		function b = eq(nsd_clock_iodevice_obj_a, nsd_clock_iodevice_obj_b)
		% EQ - are two NSD_CLOCK_IODEVICE objects equal?
		%
		% B = EQ(NDS_CLOCK_IODEVICE_OBJ_A, NSD_CLOCK_IODEVICE_OBJ_B)
		%
		% Compares two NSD_CLOCK_IODEVICE objects and returns 1 if they are refer to the same
		% device and have the same clock type.
		%
			b = nsd_clock_iodevice_obj_a.iodevice == nsd_clock_iodevice_obj_b.iodevice;
			b = b & strcmp(nsd_clock_iodevice_obj_a.type,nsd_clock_iodevice_obj_b.type);
		end % eq()

	end % methods
end % nsd_clock_iodevice class


