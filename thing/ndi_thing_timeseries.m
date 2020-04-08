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
					[data,t,timeref] = ndi_thing_timeseries_obj.underlying_thing.readtimeseries(timeref_or_epoch, t0, t1);
				else,
					if isa(timeref_or_epoch,'ndi_timereference'),
						timeref = timeref_or_epoch;
					else,
						timeref_or_epoch = ndi_thing_timeseries_obj.epochid(timeref_or_epoch);
						timeref = ndi_timereference(ndi_thing_timeseries_obj, ndi_clocktype('dev_local_time'), timeref_or_epoch, 0);
					end;

					[epoch_t0_out, epoch_timeref, msg] = ndi_thing_timeseries_obj.experiment.syncgraph.time_convert(timeref, t0, ...
							ndi_thing_timeseries_obj, ndi_clocktype('dev_local_time'));
					[epoch_t1_out, epoch_timeref, msg] = ndi_thing_timeseries_obj.experiment.syncgraph.time_convert(timeref, t1, ...
							ndi_thing_timeseries_obj, ndi_clocktype('dev_local_time'));

					% now we know the epoch to read, finally!

					thing_doc = ndi_thing_timeseries_obj.load_thing_doc();
					sq = ndi_query('depends_on','depends_on','thing_id',thing_doc.id()) & ...
						ndi_query('','isa','ndi_document_thing_epoch.json','') & ...
						ndi_query('epochid','exact_string',epoch_timeref.epoch,'');
					E = ndi_thing_timeseries_obj.experiment();
					epochdoc = E.database_search(sq);
					if numel(epochdoc)~=1,
						error(['Could not find epochdoc for epoch ' epoch_timeref.epoch ', or found too many.']);
					end;
					epochdoc = epochdoc{1};

					f = E.database_openbinarydoc(epochdoc);
					[data,t] = vhsb_read(f,epoch_t0_out,epoch_t1_out);
					E.database_closebinarydoc(f);
					
					if isnumeric(t),
						t = ndi_thing_timeseries_obj.experiment.syncgraph.time_convert(epoch_timeref, t, ...
							timeref.referent, timeref.clocktype);
					end;
				end;
		end %readtimeseries()

		%%%%% NDI_THING methods

		function [ndi_thing_timeseries_obj, epochdoc] = addepoch(ndi_thing_timeseries_obj, epochid, epochclock, t0_t1, timepoints, datapoints)
			% ADDEPOCH - add an epoch to the NDI_THING
			%
			% [NDI_THING_OBJ, EPOCHDOC] = ADDEPOCH(NDI_THING_TIMESERIES_OBJ, EPOCHID, EPOCHCLOCK, T0_T1, TIMEPOINTS, DATAPOINTS)
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
				if ndi_thing_timeseries_obj.direct,
					error(['Cannot add external observations to an NDI_THING that is directly based on another NDI_THING.']);
				end;
				[ndi_thing_timeseries_obj, epochdoc] = addepoch@ndi_thing(ndi_thing_timeseries_obj, epochid, epochclock, t0_t1);
					
				E = ndi_thing_timeseries_obj.experiment();
				f = E.database_openbinarydoc(epochdoc);
				vhsb_write(f,timepoints,datapoints,'use_filelock',0);
				E.database_closebinarydoc(f);
		end; % addepoch()

		function sr = samplerate(ndi_thing_timeseries_obj, epoch)
			et = ndi_thing_timeseries_obj.epochtableentry(epoch);
			[data, t, timeref] = readtimeseries(ndi_thing_timeseries_obj, epoch, et.t0_t1{1}(1), et.t0_t1{1}(1)+0.5);
			sr = 1/median(diff(t));
		end; % samplerate()

                function ndi_document_obj = newdocument(ndi_thing_timeseries_obj, varargin)
                        % TODO - need docs here
                                ndi_document_obj = newdocument@ndi_thing(ndi_thing_timeseries_obj, varargin{:});
                end % newdocument

                function sq = searchquery(ndi_thing_timeseries_obj, varargin)
                        % TODO - need docs here
                                sq = searchquery@ndi_thing(ndi_thing_timeseries_obj, varargin{:});
                end % searchquery

	end; % methods
end % classdef

