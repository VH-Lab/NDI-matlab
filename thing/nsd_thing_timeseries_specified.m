classef nsd_thing_timeseries_specified < nsd_thing_timeseries
% NSD_THING - define or examine a thing in the experiment
%
	properties (SetAccess=protected, GetAccess=public)

	end % properties

	methods
		function nsd_thing_timeseries_obj = nsd_thing_timeseries(thing_name, nsd_probe_obj)
			if ~isa(nsd_probe_obj, 'nsd_probe'),
				error(['NSD_PROBE_OBJ must be of type NSD_PROBE']);
			end;
			nsd_thing_obj.name = nsd_probe_obj.thing_name;
			nsd_thing_obj.probe = nsd_probe_obj;
		end; % nsd_thing_timeseries()

	% NSD_THING_TIMESERIES methods

		function [data, t, timeref] = readtimeseries(nsd_thing_timeseries_obj, timeref_or_epoch, t0, t1)
			%  READTIMESERIES - read the NSD_THING_TIMESERIES data from a probe based on specified time relative to an NSD_TIMEFERENCE or epoch
			%
			%  [DATA, T, TIMEREF] = READTIMESERIES(NSD_THING_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  Reads timeseries data from an NSD_THING_TIMESERIES object. The DATA and time information T that are
			%  returned depend on the the specific subclass of NSD_THING_TIMESERIES that is called (see READTIMESERIESEPOCH).
			%
			%  In the base class, this function merely calls the thing's probe's READTIMESERIES function. 
			%  TIMEREF_OR_EPOCH is either an NSD_TIMEREFERENCE object indicating the time reference for
			%  T0, T1, or it can be a single number, which will indicate the data are to be read from that
			%  epoch.
			%
			%  DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
			%  NSD_TIMEREFERENCE object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.
			%
				
				if isa(timeref_or_epoch,'nsd_timereference'),
					timeref = timeref_or_epoch;
				else,
					timeref = nsd_timereference(nsd_thing_timeseries_obj, nsd_clocktype('dev_local_time'), timeref_or_epoch, 0);
				end;

				[epoch_t0_out, epoch_timeref, msg] = nsd_probe_timeseries_obj.experiment.syncgraph.time_convert(timeref, t0, nsd_probe_timeseries_obj, nsd_clocktype('dev_local_time'));
				[epoch_t1_out, epoch_timeref, msg] = nsd_probe_timeseries_obj.experiment.syncgraph.time_convert(timeref, t1, nsd_probe_timeseries_obj, nsd_clocktype('dev_local_time'));

				epoch = epoch_timeref.epoch;

				if nargin <2,  % some readtimeseriesepoch() methods may be able to save time if the time information is not requested
					[data] = nsd_probe_timeseries_obj.readtimeseriesepoch(epoch, epoch_t0_out, epoch_t1_out);
				else,
					[data,t] = nsd_probe_timeseries_obj.readtimeseriesepoch(epoch, epoch_t0_out, epoch_t1_out);
					% now need to convert t back to timeref units
					if isnumeric(t),
						t = nsd_probe_timeseries_obj.experiment.syncgraph.time_convert(epoch_timeref, t, timeref.referent, timeref.clocktype);
					elseif isstruct(t),
						fn = fieldnames(t);
						for i=1:numel(fn),
							t = setfield(t, fn{i}, nsd_probe_timeseries_obj.experiment.syncgraph.time_convert(epoch_timeref, ...
								getfield(t,fn{i}), timeref.referent, timeref.clocktype));
						end
					end;
				end;

				[data,t,timeref] = nsd_thing_timeseries_obj.probe.readtimeseries(timeref_or_epoch, t0, t1);
		end %readtimeseries()

	end; % methods

end % classdef


