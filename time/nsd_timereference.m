classdef nsd_timereference
% NSD_TIMEREFERENCE - a class for specifying time relative to an NSD_CLOCK
% 
% 
	properties (SetAccess=protected, GetAccess=public)
		referent % the NSD_IODEVICE, NSD_PROBE,... that is referred to (must be a subclass of NSD_EPOCHSET)
		clocktype % the NSD_CLOCKTYPE: can be 'utc', 'exp_global_time', 'dev_global_time', or 'dev_local_time'
		epoch % the epoch that may be referred to (required if the time type is 'dev_local_time')
		time  % the time of the referent that is referred to
	end % properties

	methods
		function obj = nsd_timereference(referent, clocktype, epoch, time)
			% NSD_TIME_REFERENCE - creates a new time reference object
			%
			% OBJ = NSD_TIME_REFERENCE(REFERENT, CLOCKTYPE, EPOCH, TIME)
			%
			% Creates a new NSD_TIME_REFERENCE object. The REFERENT, EPOCH, and TIME must
			% specify a unique time. 
			%
			% REFERENT is any subclass of NSD_EPOCHSET object (NSD_IODEVICE, NSD_PROBE, etc...)
			% TYPE is the time type, can be 'utc', 'exp_global_time', or 'dev_global_time' or 'dev_local_time'
			% If TYPE is 'dev_local_time', then the EPOCH identifier is necessary. Otherwise, it can be empty.
			% If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
			% device associated with CLOCK, even if the device keeps universal or time.
			%
			% An alternative creator is available:
			%
			% OBJ = NSD_TIME_REFERENCE(NSD_EXPERIMENT_OBJ, NSD_TIMEREF_STRUCT)
			%
			% where NSD_EXPERIMENT_OBJ is an NSD_EXPERIMENT and NSD_TIMEREF_STRUCT is a structure
			% returned by NSD_TIMEREFERENCE/NSD_TIMEREFERENCE_STRUCT. The NSD_EXPERIMENT_OBJ fields will
			% be searched to find the live REFERENT to create OBJ.
			%

				if nargin==2,
					experiment = referent; % 1st argument
					timeref_struct = clocktype; % 2nd argument
					referent = experiment.findexpobj(timeref_struct.referent_epochsetname,timeref_struct.referent_classname);
					clocktype = nsd_clocktype(timeref_struct.clocktypestring);
					epoch = timeref_struct.epoch;
					time = timeref_struct.time;
				end;

				if ~ ( isa(referent,'nsd_epochset') ),
					error(['referent must be a subclass of NSD_EPOCHSET.']);
				end

				if ~isa(clocktype,'nsd_clocktype'),
					error(['clocktype must be a member or subclass of NSD_CLOCKTYPE.']);
				end

				if clocktype.needsepoch(),
					if isempty(epoch),
						error(['time is local; an EPOCH must be specified.']);
					end
				end;

				obj.referent = referent;
				obj.clocktype = clocktype;
				obj.epoch = epoch;
				obj.time = time;
		end % nsd_time_reference

		function a = nsd_timereference_struct(nsd_timeref_obj)
			% NSD_TIMEREFERENCE_STRUCT - return a structure that describes an NSD_TIMEREFERENCE object that lacks Matlab objects
			%
			% A = NSD_TIMEREFERENCE_STRUCT(NSD_TIMEREF_OBJ)
			%
			% Returns a structure with the following fields:
			% Fieldname                      | Description
			% --------------------------------------------------------------------------------
			% referent_epochsetname          | The epochsetname() of the referent
			% referent_classname             | The classname of the referent
			% clocktypestring                | The value of the clocktype
			% epoch                          | The epoch (either a string or a number)
			% time                           | The time
			% 
				a.referent_epochsetname = nsd_timeref_obj.referent.epochsetname();
				a.referent_classname = class(nsd_timeref_obj.referent);
				a.clocktypestring = nsd_timeref_obj.clocktype.type;
				a.epoch = nsd_timeref_obj.epoch;
				a.time = nsd_timeref_obj.time;
		end % nsd_timereference_struct

	end % methods
end % nsd_time_reference

