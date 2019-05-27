classdef ndi_timereference
% NDI_TIMEREFERENCE - a class for specifying time relative to an NDI_CLOCK
% 
% 
	properties (SetAccess=protected, GetAccess=public)
		referent % the NDI_IODEVICE, NDI_PROBE,... that is referred to (must be a subclass of NDI_EPOCHSET)
		clocktype % the NDI_CLOCKTYPE: can be 'utc', 'exp_global_time', 'dev_global_time', or 'dev_local_time'
		epoch % the epoch that may be referred to (required if the time type is 'dev_local_time')
		time  % the time of the referent that is referred to
	end % properties

	methods
		function obj = ndi_timereference(referent, clocktype, epoch, time)
			% NDI_TIME_REFERENCE - creates a new time reference object
			%
			% OBJ = NDI_TIME_REFERENCE(REFERENT, CLOCKTYPE, EPOCH, TIME)
			%
			% Creates a new NDI_TIME_REFERENCE object. The REFERENT, EPOCH, and TIME must
			% specify a unique time. 
			%
			% REFERENT is any subclass of NDI_EPOCHSET object (NDI_IODEVICE, NDI_PROBE, etc...)
			% TYPE is the time type, can be 'utc', 'exp_global_time', or 'dev_global_time' or 'dev_local_time'
			% If TYPE is 'dev_local_time', then the EPOCH identifier is necessary. Otherwise, it can be empty.
			% If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
			% device associated with CLOCK, even if the device keeps universal or time.
			%
			% An alternative creator is available:
			%
			% OBJ = NDI_TIME_REFERENCE(NDI_EXPERIMENT_OBJ, NDI_TIMEREF_STRUCT)
			%
			% where NDI_EXPERIMENT_OBJ is an NDI_EXPERIMENT and NDI_TIMEREF_STRUCT is a structure
			% returned by NDI_TIMEREFERENCE/NDI_TIMEREFERENCE_STRUCT. The NDI_EXPERIMENT_OBJ fields will
			% be searched to find the live REFERENT to create OBJ.
			%

				if nargin==2,
					experiment = referent; % 1st argument
					timeref_struct = clocktype; % 2nd argument
					referent = experiment.findexpobj(timeref_struct.referent_epochsetname,timeref_struct.referent_classname);
					clocktype = ndi_clocktype(timeref_struct.clocktypestring);
					epoch = timeref_struct.epoch;
					time = timeref_struct.time;
				end;

				if ~ ( isa(referent,'ndi_epochset') ),
					error(['referent must be a subclass of NDI_EPOCHSET.']);
				end

				if ~isa(clocktype,'ndi_clocktype'),
					error(['clocktype must be a member or subclass of NDI_CLOCKTYPE.']);
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
		end % ndi_time_reference

		function a = ndi_timereference_struct(ndi_timeref_obj)
			% NDI_TIMEREFERENCE_STRUCT - return a structure that describes an NDI_TIMEREFERENCE object that lacks Matlab objects
			%
			% A = NDI_TIMEREFERENCE_STRUCT(NDI_TIMEREF_OBJ)
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
				a.referent_epochsetname = ndi_timeref_obj.referent.epochsetname();
				a.referent_classname = class(ndi_timeref_obj.referent);
				a.clocktypestring = ndi_timeref_obj.clocktype.ndi_clocktype2char();
				a.epoch = ndi_timeref_obj.epoch;
				a.time = ndi_timeref_obj.time;
		end % ndi_timereference_struct

	end % methods
end % ndi_time_reference

