classdef nsd_timeseries
% NSD_TIMESERIES - abstract class for managing time series data
%
        properties (SetAccess=protected,GetAccess=public)
        end % properties
        properties (SetAccess=protected,GetAccess=protected)
		
        end % properties

        methods

		function nsd_timeseries_obj = nsd_timeseries(varargin)
			% NSD_TIMESERIES - create an NSD_TIMESERIES object
			%
			% NSD_TIMESERIES_OBJ = NSD_TIMESERIES()
			%
			% This function creates an NSD_TIMESERIES object, which is an
			% abstract class that defines methods for other objects that deal with
			% time series.
			%
		end % nsd_timeseries()

		function [data, t, timeref] = readtimeseries(nsd_probe_timeseries_obj, timeref_or_epoch, t0, t1)
			%  READTIMESERIES - read a time series from this parent object (NSD_TIMESERIES) 
			%
			%  [DATA, T, TIMEREF] = READTIMESERIES(NSD_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  Reads timeseries data from an NSD_TIMESERIES object. The DATA and time information T that are
			%  returned depend on the the specific subclass of NSD_TIMESERIES that is called (see READTIMESERIESEPOCH).
			%
			%  TIMEREF_OR_EPOCH is either an NSD_TIMEREFERENCE object indicating the time reference for
			%  T0, T1, or it can be a single number, which will indicate the data are to be read from that
			%  epoch.
			%
			%  DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
			%  NSD_TIMEREFERENCE object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.

		end; % readtimeseries()

	end % methods
end % class nsd_timereference

