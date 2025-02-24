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

            [epoch_t0_out, epoch0_timeref, msg] = ndi_probe_timeseries_obj.session.syncgraph.time_convert(timeref, t0, ...
                ndi_probe_timeseries_obj, ndi.time.clocktype('dev_local_time'));
            [epoch_t1_out, epoch1_timeref, msg] = ndi_probe_timeseries_obj.session.syncgraph.time_convert(timeref, t1, ...
                ndi_probe_timeseries_obj, ndi.time.clocktype('dev_local_time'));

            if isempty(epoch0_timeref) | isempty(epoch1_timeref)
                error(['Could not find time mapping (maybe wrong epoch name?): ' msg ]);
            end

            [er,et,gt0_t1] = ndi.epoch.epochrange(epoch0_timeref.referent,ndi.time.clocktype('dev_local_time'),epoch0_timeref.epoch,epoch1_timeref.epoch);

            epoch = epoch0_timeref.epoch;

            data = [];
            t = [];

            if nargin <2,  % some readtimeseriesepoch() methods may be able to save time if the time information is not requested
                for i=1:numel(er)
                    if (i==1)
                        startTime = epoch_t0_out;
                    else
                        startTime = gt0_t1(i,1);
                    end
                    if (i==numel(er))
                        stopTime = epoch_t1_out;
                    else
                        stopTime = gt0_t1(i,2);
                    end
                    [data_here] = ndi_probe_timeseries_obj.readtimeseriesepoch(er{i}, startTime, stopTime);
                    data = cat(1,data,data_here);
                end
            else
                for i=1:numel(er)
                    if (i==1)
                        startTime = epoch_t0_out;
                    else
                        startTime = gt0_t1(i,1);
                    end
                    if (i==numel(er))
                        stopTime = epoch_t1_out;
                    else
                        stopTime = gt0_t1(i,2);
                    end
                    [data_here,t_here] = ndi_probe_timeseries_obj.readtimeseriesepoch(er{i}, startTime, stopTime);
                    t_here = t_here(:);
                    data = cat(1,data,data_here);                    
                    % now need to convert t back to timeref units
                    epoch_here_timeref = ndi.time.timereference(epoch0_timeref.referent,epoch0_timeref.clocktype,er{i},epoch0_timeref.time);
                    if isnumeric(t_here)
                        t_here = ndi_probe_timeseries_obj.session.syncgraph.time_convert(epoch_here_timeref, t_here, timeref.referent, timeref.clocktype);
                        t = cat(1,t,t_here);
                    elseif isstruct(t_here)
                        fn = fieldnames(t_here);
                        for j=1:numel(fn)
                            t_data_here = getfield(t_here,fn{j});
                            if isfield(t,fn{j})
                                t_old = getfield(t,fn{j});
                            else
                                t_old = [];
                            end
                            if ~iscell(t_data_here)
                                t_here = setfield(t_here, fn{j}, ndi_probe_timeseries_obj.session.syncgraph.time_convert(epoch_here_timeref, ...
                                    t_data_here, timeref.referent, timeref.clocktype));
                                t = setfield(t,fn{j},cat(1,t_old,getfield(t_here,fn{j})));
                            else
                                for jj=1:numel(t_data_here)
                                    t_data_here{jj} = ndi_probe_timeseries_obj.session.syncgraph.time_convert(epoch_here_timeref, ...
                                        t_data_here{jj}, timeref.referent, timeref.clocktype);
                                    if isempty(t_old) & numel(t_old)<jj
                                        t_new{jj} = t_data_here{jj};
                                    else
                                        t_new{jj} = cat(1,t_old{jj},t_data_here{jj});
                                    end
                                end
                                t = setfield(t, fn{j}, t_new); % t_data_here is a set of cell arrays
                            end                            
                        end
                    end
                end
            end
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
