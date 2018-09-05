classdef nsd_timereference
% NSD_TIME_REFERENCE - a class for specifying time relative to an NSD_CLOCK
% 
% 
	properties (SetAccess=protected, GetAccess=public)
		referent % the NSD_CLOCK_IODEVICE, NSD_IODEVICE, NSD_PROBE,... that is referred to that has an underlying NSD_CLOCK
		type % the time type, can be 'utc', 'exp_global_time', 'dev_global_time', or 'dev_local_time'
		epoch % the epoch that may be referred to (required if the time type is 'dev_local_time')
		time  % the time on the clock (and epoch) that is referred to
	end % properties

	methods
		function obj = nsd_timereference(referent, type, epoch, time)
			% NSD_TIME_REFERENCE - creates a new time reference object
			%
			% OBJ = NSD_TIME_REFERENCE(REFERENT, TYPE, EPOCH, TIME)
			%
			% Creates a new NSD_TIME_REFERENCE object. The REFERENT, EPOCH, and TIME must
			% specify a unique time. 
			%
			% REFERENT is an NSD_CLOCK_IODEVICE, NSD_IODEVICE, NSD_PROBE object
			% TYPE is the time type, can be 'utc', 'exp_global_time', or 'dev_global_time' or 'dev_local_time'
			% If TYPE is 'dev_local_time', then the EPOCH identifier is necessary. Otherwise, it can be empty.
			% If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
			% device associated with CLOCK, even if the device keeps universal or time.
			%
				if strcmp(lower(type),'dev_local_time'),
					if isempty(epoch),
						error(['time is local; an EPOCH must be specified.']);
					end
				end;

				obj.referent = referent;
				obj.type = type;
				obj.epoch = epoch;
				obj.time = time;
		end % nsd_time_reference

	end % methods
end % nsd_time_reference
