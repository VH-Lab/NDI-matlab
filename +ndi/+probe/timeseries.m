classdef timeseries < ndi.probe & ndi.time.timeseries
% ndi.probe.timeseries - Create a new ndi.probe.timeseries class object 
%
	properties (GetAccess=public, SetAccess=protected)
	end

	methods
		function obj = timeseries(varargin)
			% ndi.probe.timeseries - create a new ndi.probe.timeseries object
			%
			%  OBJ = ndi.probe.timeseries(SESSION, NAME, REFERENCE, TYPE)
			%
			%  Creates an ndi.probe associated with an ndi.session object SESSION and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  ndi.probe.timeseries is an abstract class, and a specific implementation must be called.
			%
				obj = obj@ndi.probe(varargin{:});
		end % ndi.probe.timeseries

		function [data, t, timeref] = readtimeseries(ndi_probe_timeseries_obj, timeref_or_epoch, t0, t1)
			%  READTIMESERIES - read the probe data based on specified time relative to an NDI_TIMEFERENCE or epoch
			%
			%  [DATA, T, TIMEREF] = READTIMESERIES(NDI_PROBE_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
			%
			%  Reads timeseries data from an ndi.probe.timeseries object. The DATA and time information T that are
			%  returned depend on the the specific subclass of ndi.probe.timeseries that is called (see READTIMESERIESEPOCH).
			%
			%  TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the time reference for
			%  T0, T1, or it can be a single number, which will indicate the data are to be read from that
			%  epoch.
			%
			%  DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
			%  ndi.time.timereference object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.
			%
				if isa(timeref_or_epoch,'ndi.time.timereference'),
					timeref = timeref_or_epoch;
				else,
					timeref = ndi.time.timereference(ndi_probe_timeseries_obj, ndi.time.clocktype('dev_local_time'), timeref_or_epoch, 0);
				end;
				
				[epoch_t0_out, epoch_timeref, msg] = ndi_probe_timeseries_obj.session.syncgraph.time_convert(timeref, t0, ...
					ndi_probe_timeseries_obj, ndi.time.clocktype('dev_local_time'));
				[epoch_t1_out, epoch_timeref, msg] = ndi_probe_timeseries_obj.session.syncgraph.time_convert(timeref, t1, ...
					ndi_probe_timeseries_obj, ndi.time.clocktype('dev_local_time'));

				if isempty(epoch_timeref),
					error(['Could not find time mapping (maybe wrong epoch name?): ' msg ]);
				end;

				epoch = epoch_timeref.epoch;

				if nargin <2,  % some readtimeseriesepoch() methods may be able to save time if the time information is not requested
					[data] = ndi_probe_timeseries_obj.readtimeseriesepoch(epoch, epoch_t0_out, epoch_t1_out);
				else,
					[data,t] = ndi_probe_timeseries_obj.readtimeseriesepoch(epoch, epoch_t0_out, epoch_t1_out);
					% now need to convert t back to timeref units
					if isnumeric(t),
						t = ndi_probe_timeseries_obj.session.syncgraph.time_convert(epoch_timeref, t, timeref.referent, timeref.clocktype);
					elseif isstruct(t),
						fn = fieldnames(t);
						for i=1:numel(fn),
							t_data_here = getfield(t,fn{i});
							if ~iscell(t_data_here),
								t = setfield(t, fn{i}, ndi_probe_timeseries_obj.session.syncgraph.time_convert(epoch_timeref, ...
									t_data_here, timeref.referent, timeref.clocktype));
							else,
								for jj=1:numel(t_data_here),
									t_data_here{jj} = ndi_probe_timeseries_obj.session.syncgraph.time_convert(epoch_timeref, ...
									t_data_here{jj}, timeref.referent, timeref.clocktype);
								end;
								t = setfield(t, fn{i}, t_data_here);
							end;
						end
					end;
				end;
		end %readtimeseries()

		function ndi_document_obj = newdocument(ndi_probe_timeseries_obj, varargin)
			% TODO - need docs here
				ndi_document_obj = newdocument@ndi.probe(ndi_probe_timeseries_obj, varargin{:});
		end % newdocument

		function sq = searchquery(ndi_probe_timeseries_obj, varargin)
			% TODO - need docs here
				sq = searchquery@ndi.probe(ndi_probe_timeseries_obj, varargin{:});
		end % newdocument

	end; % methods
end


