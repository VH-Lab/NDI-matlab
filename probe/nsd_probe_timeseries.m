classdef nsd_probe_timeseries < nsd_probe
% NSD_PROBE_TIMESERIES - Create a new NSD_PROBE_MFAQ class object that handles probes that are associated with NSD_IODEVICE_MFDAQ objects
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = nsd_probe_timeseries(experiment, name, reference, type)
			% NSD_PROBE_TIMESERIES - create a new NSD_PROBE_TIMESERIES object
			%
			%  OBJ = NSD_PROBE_TIMESERIES(EXPERIMENT, NAME, REFERENCE, TYPE)
			%
			%  Creates an NSD_PROBE associated with an NSD_EXPERIMENT object EXPERIMENT and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  NSD_PROBE_TIMESERIES is an abstract class, and a specific implementation must be called.
			%
				obj = obj@nsd_probe(experiment, name, reference, type);

		end % nsd_probe_timeseries

		function [data, t, timeref] = readtimeseries(nsd_probe_timeseries_obj, timeref_or_epoch, t0, t1)
			%  READTIMESERIES - read the probe data based on specified time relative to an NSD_TIMEFERENCE or epoch
			%
			%  [DATA, T, TIMEREF] = READTIMESERIES(NSD_PROBE_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  Reads timeseries data from an NSD_PROBE_TIMESERIES object. The DATA and time information T that are
			%  returned depend on the the specific subclass of NSD_PROBE_TIMESERIES that is called (see READTIMESERIESEPOCH).
			%
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
					timeref = nsd_timereference(nsd_probe_timeseries_obj, nsd_clocktype('dev_local_time'), timeref_or_epoch, 0);
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
		end %readtimeseries()

	end; % methods
end


