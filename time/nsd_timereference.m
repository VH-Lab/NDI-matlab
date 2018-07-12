classdef nsd_timereference
% NSD_TIME_REFERENCE - a class for specifying time relative to an NSD_CLOCK
% 
% 
	properties (SetAccess=protected, GetAccess=public)
		clock % the NSD_CLOCK that is referred to
		epoch % the epoch that may be referred to (required if clock type is 'dev_local_time')
		time  % the time on the clock (and epoch) that is referred to
	end % properties

	methods
		function obj = nsd_timereference(clock, epoch, time)
			% NSD_TIME_REFERENCE - creates a new time reference object
			%
			% OBJ = NSD_TIME_REFERENCE(CLOCK, EPOCH, TIME)
			%
			% Creates a new NSD_TIME_REFERENCE object. The CLOCK, EPOCH, and TIME must
			% specify a unique time. 
			%
			% CLOCK is an NSD_CLOCK_IODEVICE object.
			% If the CLOCK.type is 'utc', 'exp_global_time', or 'dev_global_time', then
			% EPOCH can be empty; it is not necessary to specify the time.
			% If the CLOCK.type is 'dev_local_time', then the EPOCH identifier is necessary
			% to specify the time.
			% If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
			% device associated with CLOCK, even if the device keeps universal or time.
			%
				if ~isa(clock, lower('NSD_CLOCK_IODEVICE')),
					error(['CLOCK must be an NSD_CLOCK_IODEVICE object.']);
				end;

				if strcmp(lower(clock.type),'dev_local_time'),
					if isempty(epoch),
						error(['CLOCK only has local time; an EPOCH must be specified.']);
					end
				end;

				obj.clock = clock;
				obj.epoch = epoch;
				obj.time = time;
		end % nsd_time_reference

	end % methods
end % nsd_time_reference

