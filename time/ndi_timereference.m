classdef ndi_timereference
% NDI_TIMEREFERENCE - a class for specifying time relative to an NDI_CLOCK
% 
% 
	properties (SetAccess=protected, GetAccess=public)
		referent % the NDI_DAQSYSTEM, NDI_PROBE,... that is referred to (must be a subclass of NDI_EPOCHSET)
		clocktype % the NDI_CLOCKTYPE: can be 'utc', 'exp_global_time', 'dev_global_time', or 'dev_local_time'
		epoch % the epoch that may be referred to (required if the time type is 'dev_local_time')
		time  % the time of the referent that is referred to
		session_ID % the ID of the session that contains the time
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
			% REFERENT is any subclass of NDI_EPOCHSET object that has a 'session' property
			%   (e.g., NDI_DAQSYSTEM, NDI_ELEMENT, etc...).
			% TYPE is the time type, can be 'utc', 'exp_global_time', or 'dev_global_time' or 'dev_local_time'
			% If TYPE is 'dev_local_time', then the EPOCH identifier is necessary. Otherwise, it can be empty.
			% If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
			% device associated with CLOCK, even if the device keeps universal or time.
			%
			% An alternative creator is available:
			%
			% OBJ = NDI_TIME_REFERENCE(NDI_SESSION_OBJ, NDI_TIMEREF_STRUCT)
			%
			% where NDI_SESSION_OBJ is an NDI_SESSION and NDI_TIMEREF_STRUCT is a structure
			% returned by NDI_TIMEREFERENCE/NDI_TIMEREFERENCE_STRUCT. The NDI_SESSION_OBJ fields will
			% be searched to find the live REFERENT to create OBJ.
			%

				if nargin==2,
					session = referent; % 1st argument
					session_ID = session.id();
					timeref_struct = clocktype; % 2nd argument
					% THINK: does this need to change for situations involving multiple sessions?
					referent = session.findexpobj(timeref_struct.referent_epochsetname,timeref_struct.referent_classname);
					clocktype = ndi_clocktype(timeref_struct.clocktypestring);
					epoch = timeref_struct.epoch;
					time = timeref_struct.time;
				end;

				if ~( isa(referent,'ndi_epochset') ), 
	 				error(['referent must be a subclass of NDI_EPOCHSET.']);
				else,
					if isprop(referent,'session'),
						if ~isa(referent.session,'ndi_session'),
							error(['The referent must have an ndi_session with a valid id.']);
						else,
							session_ID = referent.session.id(); % TODO: this doesn't explicitly check out from types
						end;
					else,
						error(['The referent must have a session with a valid id.']);
					end;
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
				obj.session_ID = session_ID;
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
			% session_ID                     | The session ID of the session that contains the epoch
			% time                           | The time
			% 
				a.referent_epochsetname = ndi_timeref_obj.referent.epochsetname();
				a.referent_classname = class(ndi_timeref_obj.referent);
				a.clocktypestring = ndi_timeref_obj.clocktype.ndi_clocktype2char();
				a.epoch = ndi_timeref_obj.epoch;
				a.session_ID = ndi_timeref_obj.session_ID;
				a.time = ndi_timeref_obj.time;
		end % ndi_timereference_struct

	end % methods
end % ndi_time_reference

