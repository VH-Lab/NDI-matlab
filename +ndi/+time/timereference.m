classdef timereference
% NDI.TIME.TIMEREFERENCE - a class for specifying time relative to an NDI_CLOCK
% 
% 
	properties (SetAccess=protected, GetAccess=public)
		referent % the ndi.daq.system, ndi.probe.*,... that is referred to (must be a subclass of ndi.epoch.epochset)
		clocktype % the ndi.time.clocktype: can be 'utc', 'exp_global_time', 'dev_global_time', or 'dev_local_time'
		epoch % the epoch that may be referred to (required if the time type is 'dev_local_time')
		time  % the time of the referent that is referred to
		session_ID % the ID of the session that contains the time
	end % properties

	methods
		function obj = timereference(referent, clocktype, epoch, time)
			% NDI.TIME.TIME.REFERENCE - creates a new time reference object
			%
			% OBJ = NDI.TIME.TIMEREFERENCE(REFERENT, CLOCKTYPE, EPOCH, TIME)
			%
			% Creates a new ndi.time.timereference object. The REFERENT, EPOCH, and TIME must
			% specify a unique time. 
			%
			% REFERENT is any subclass of ndi.epoch.epochset object that has a 'session' property
			%   (e.g., ndi.daq.system, ndi.element, etc...).
			% TYPE is the time type, can be 'utc', 'exp_global_time', or 'dev_global_time' or 'dev_local_time'
			% If TYPE is 'dev_local_time', then the EPOCH identifier is necessary. Otherwise, it can be empty.
			% If EPOCH is specified, then TIME is taken to be relative to the EPOCH number of the
			% device associated with CLOCK, even if the device keeps universal or time.
			%
			% An alternative creator is available:
			%
			% OBJ = ndi.time.timereference(NDI_SESSION_OBJ, NDI_TIMEREF_STRUCT)
			%
			% where NDI_SESSION_OBJ is an ndi.session.session and NDI_TIMEREF_STRUCT is a structure
			% returned by ndi.time.timereference/NDI_TIMEREFERENCE_STRUCT. The NDI_SESSION_OBJ fields will
			% be searched to find the live REFERENT to create OBJ.
			%

				if nargin==2,
					session = referent; % 1st argument
					session_ID = session.id();
					timeref_struct = clocktype; % 2nd argument
					% THINK: does this need to change for situations involving multiple sessions?
					referent = session.findexpobj(timeref_struct.referent_epochsetname,timeref_struct.referent_classname);
					clocktype = ndi.time.clocktype(timeref_struct.clocktypestring);
					epoch = timeref_struct.epoch;
					time = timeref_struct.time;
				end;

				if ~( isa(referent,'ndi.epoch.epochset') ), 
	 				error(['referent must be a subclass of ndi.epoch.epochset.']);
				else,
					if isprop(referent,'session') | ismethod(referent,'session'),
						if ~isa(referent.session,'ndi.session.session'),
							error(['The referent must have an ndi.session.session with a valid id.']);
						else,
							session_ID = referent.session.id(); % TODO: this doesn't explicitly check out from types
						end;
					else,
						error(['The referent must have a session with a valid id.']);
					end;
				end

				if ~isa(clocktype,'ndi.time.clocktype'),
					error(['clocktype must be a member or subclass of ndi.time.clocktype.']);
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
			% NDI_TIMEREFERENCE_STRUCT - return a structure that describes an ndi.time.timereference object that lacks Matlab objects
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

