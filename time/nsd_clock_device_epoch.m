classdef nsd_clock_device_epoch < nsd_clock_device
% NSD_CLOCK_DEVICE_EPOCH - a class for specifying time with respect to an epoch on an NSD_DEVICE
%
%
	properties (SetAccess=protected, GetAccess=public)
		epoch % the epoch number or identifier to be referred to
	end

	methods
		function obj = nsd_clock_device_epoch(varargin)
			% NSD_CLOCK_DEVICE_EPOCH - Creates a new NSD_CLOCK_DEVICE_EPOCH object, which refers to a specific epoch
			%
			% Creates a new NSD_CLOCK_DEVICE_EPOCH object. There are two forms of the constructor:
			%
			% OBJ = NSD_CLOCK_DEVICE_EPOCH(TYPE, DEVICE, EPOCH)
			%    or
			% OBJ = NSD_CLOCK_DEVICE_EPOCH(NSD_CLOCK_DEVICE_OBJ, EPOCH)
			%
			% One can specify the TYPE, DEVICE, and EPOCH, or can specify the TYPE and
			% DEVICE from an existing NSD_CLOCK_DEVICE object NSD_CLOCK_DEVICE_OBJ.
			% TYPE can be any of the following strings (with description):
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The device keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
			% 'no_time'          | The device has no timing information
			% 'dev_global_time'  | The device has a global clock for itself
			% 'dev_local_time'   | The device only has local time, within a recording epoch
			%
				type='';
				device=[];
				epoch=[];
				if nargin==2,
					myclock = varargin{1};
					epoch = varargin{2};
					if isa(myclock,'nsd_clock_device'),
						type = myclock.type;
						device = myclock.device;
					else,
						error(['When called with 2 inputs, first input must be an NSD_CLOCK_DEVICE object.']);
					end
				elseif nargin==3,
					type = varargin{1};
					device = varargin{2};
					epoch = varargin{3};
				elseif nargin==0,
				else,
					error(['Function must have 0, 2, or 3 input arguments.']);
				end
				obj=obj@nsd_clock_device(type, device);
				obj.epoch = epoch;
		end % nsd_clock_device_epoch()

		function nsd_clock_device_epoch_obj = setepoch(nsd_clock_device_epoch_obj, epoch)
			% SETEPOCH - Set the epoch of an NSD_CLOCK_DEVICE_EPOCH object
			%
			% NSD_CLOCK_DEVICE_EPOCH_OBJ = SETEPOCH(NSD_CLOCK_DEVIE_EPOCH_OBJ, EPOCH)
			%
			% Set the epoch property of an NSD_CLOCK_DEVICE_EPOCH object to EPOCH.
			%
			% This value can be read from NSD_CLOCK_DEVICE_EPOCH_OBJ.epoch
			%
				nsd_clock_device_epoch.epoch = epoch;
		end % setepoch
	end % methods
end % nsd_clock_device_epoch class


