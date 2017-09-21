classdef nsd_clock_device < nsd_clock
% NSD_CLOCK_DEVICE - a class for specifying time in the NSD framework for clocks that are linked to NSD_DEVICE objects
%
	properties (SetAccess=protected, GetAccess=public)
		device % the nsd_device object associated with the clock
	end

	methods
		function obj = nsd_clock_device(varargin)
			% NSD_CLOCK_DEVICE - Creates a new NSD_CLOCK_DEVICE object, an NSD_CLOCK associated with a device
			%
			% OBJ = NSD_CLOCK_DEVICE(TYPE, DEVICE)
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

				type = '';
				device = [];
				fullfilename = '';

				if nargin==0,
					return;
				end

				if nargin==2,
					if strcmp(lower(varargin{2}),lower('OpenFile'))
						fullfilename = varargin{1};
					else,
						type = varargin{1};
						device = varargin{2};
                                        end
                                end

				if ~isempty(fullfilename),
					obj = obj.readobjectfile(fullfilename);
				end

				if ~isempty(type),
					obj = obj.setclocktype(type);
				end

				if ~isempty(device),
					obj = setdevice(obj,device);
				end

		end % nsd_clock_device()
		
		function nsd_clock_device_obj = setclocktype(nsd_clock_device_obj, type)
			% SETCLOCKTYPE - Set the type of an NSD_CLOCK_DEVICE
			%
			% NSD_CLOCK_DEVICE_OBJ = SETCLOCKTYPE(NSD_CLOCK_DEVICE_OBJ, TYPE)
			%
			% Sets the TYPE property of an NSD_CLOCK_DEVICE object NSD_CLOCK_DEVICE_OBJ.
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
					nsd_clock_device_obj = setclocktype@nsd_clock_device_obj(nsd_clock_device_obj,type);
					return;
				catch,
					type = lower(type);
					switch type,
						case {'dev_global_time','dev_local_time'},
							% no error
						otherwise,
							error(['Unknown clock type ' type '.']);
					end
					nsd_clock_device_obj.type = type;
				end
		end % setclocktype() %

		function nsd_clock_device_obj = setdevice(nsd_clock_device_obj, device)
			% SETDEVICE - set the device of an NSD_CLOCK_DEVICE object
			%
			% NSD_CLOCK_DEVICE_OBJ = SETDEVICE(NSD_CLOCK_DEVICE_OBJ, DEVICE)
			%
			% Sets the current device for an NSD_CLOCK_DEVICE_OBJ.
			%

				if ~isa(device,'nsd_device'),
					error(['The device must be an NSD_DEVICE object or one of its children.']);
				end
				nsd_clock_device_obj.device = device;
		end

	end % methods
end % nsd_clock_device class

