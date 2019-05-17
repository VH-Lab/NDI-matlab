classdef ndi_thing_timeseries < ndi_thing & ndi_timeseries
% NDI_THING - define or examine a thing in the experiment
%
	properties (SetAccess=protected, GetAccess=public)

	end % properties

	methods
		function ndi_thing_timeseries_obj = ndi_thing_timeseries(varargin)
			ndi_thing_timeseries_obj = ndi_thing_timeseries_obj@ndi_thing(varargin{:});
		end; % ndi_thing_timeseries()

		%%%%% NDI_TIMESERIES methods

		function [data, t, timeref] = readtimeseries(ndi_thing_timeseries_obj, timeref_or_epoch, t0, t1)
			%  READTIMESERIES - read the NDI_THING_TIMESERIES data from a probe based on specified time relative to an NDI_TIMEFERENCE or epoch
			%
			%  [DATA, T, TIMEREF] = READTIMESERIES(NDI_THING_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  Reads timeseries data from an NDI_THING_TIMESERIES object. The DATA and time information T that are
			%  returned depend on the the specific subclass of NDI_THING_TIMESERIES that is called (see READTIMESERIESEPOCH).
			%
			%  In the base class, this function merely calls the thing's probe's READTIMESERIES function. 
			%  TIMEREF_OR_EPOCH is either an NDI_TIMEREFERENCE object indicating the time reference for
			%  T0, T1, or it can be a single number, which will indicate the data are to be read from that
			%  epoch.
			%
			%  DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
			%  NDI_TIMEREFERENCE object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.
			%
				if ndi_thing_timeseries_obj.direct,
					[data,t,timeref] = ndi_thing_timeseries_obj.probe.readtimeseries(timeref_or_epoch, t0, t1);
				else,
				end;
		end %readtimeseries()

		%%%%% NDI_THING methods

		function [ndi_thing_obj, epochdoc] = addepoch(ndi_thing_obj, epochid, epochclock, t0_t1, timepoints, datapoints, series)
			% ADDEPOCH - add an epoch to the NDI_THING
			%
			% [NDI_THING_OBJ, EPOCHDOC] = ADDEPOCH(NDI_THING_OBJ, EPOCHID, EPOCHCLOCK, T0_T1)
			%
			% Registers the data for an epoch with the NDI_THING_OBJ.
			%
			% Inputs:
			%   NDI_THING_OBJ: The NDI_THING object to modify
			%   EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
			%   EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
			%                     of the probe
			%   T0_T1:         The starting time and ending time of the existence of information about the THING on
			%                     the probe, in units of the epock clock
			%   TIMEPOINTS:    the time points to be added to this epoch; can also be the string 'probe' which means the
			%                     points are read directly from the probe (must be Tx1). Timepoints must be in the units
			%                     of the EPOCHCLOCK.
			%   DATAPOINTS:    the data points that accompany each timepoint (must be TxXxY...), or can be 'probe' to
			%                     read from the probe
			% Outputs:
			%    If a second output is requested in EPOCHDOC, then the DOC is NOT added to the database
			%  
				if ndi_thing_obj.direct,
					error(['Cannot add external observations to an NDI_THING that is directly based on NDI_PROBE.']);
				end;
				[ndi_thing_timeseries_obj, epochdoc] = addepoch@ndi_thing(ndi_thing_timeseries_obj, epochid, epochclock, t0_t1);
					
				E = [];
				if ~isempty(ndi_thing_obj.probe),
					E = ndi_thing_obj.probe.experiment;
				end;
		end; % addepoch()
	end; % methods
end % classdef

