classdef timeseries < ndi.element & ndi.time.timeseries
    % NDI_ELEMENT - define or examine a element in the session
    %
    properties (SetAccess=protected, GetAccess=public)

    end % properties

    methods
        function [ndi_element_timeseries_obj] = timeseries(varargin)
            [ndi_element_timeseries_obj] = ndi_element_timeseries_obj@ndi.element(varargin{:});
        end % ndi.element.timeseries()

        %%%%% ndi.time.timeseries methods

        function [data, t, timeref] = readtimeseries(ndi_element_timeseries_obj, timeref_or_epoch, t0, t1)
            %  READTIMESERIES - read the ndi.element.timeseries data from a probe based on specified time relative to an NDI_TIMEFERENCE or epoch
            %
            %  [DATA, T, TIMEREF] = READTIMESERIES(NDI_ELEMENT_TIMESERIES_OBJ, TIMEREF_OR_EPOCH, T0, T1)
            %
            %  Reads timeseries data from an ndi.element.timeseries object. The DATA and time information T that are
            %  returned depend on the the specific subclass of ndi.element.timeseries that is called (see READTIMESERIESEPOCH).
            %
            %  In the base class, this function merely calls the element's probe's READTIMESERIES function.
            %  TIMEREF_OR_EPOCH is either an ndi.time.timereference object indicating the time reference for
            %  T0, T1, or it can be a single number, which will indicate the data are to be read from that
            %  epoch.
            %
            %  DATA is the data for the probe.  T is a time structure, in units of TIMEREF if it is an
            %  ndi.time.timereference object or in units of the epoch if an epoch is passed.  The TIMEREF is returned.
            %
            if ndi_element_timeseries_obj.direct
                [data,t,timeref] = ndi_element_timeseries_obj.underlying_element.readtimeseries(timeref_or_epoch, t0, t1);
            else
                if isa(timeref_or_epoch,'ndi.time.timereference')
                    timeref = timeref_or_epoch;
                else
                    timeref_or_epoch = ndi_element_timeseries_obj.epochid(timeref_or_epoch);
                    % find the first type of epochclock listed for this epoch
                    et_entry = ndi_element_timeseries_obj.epochtableentry(timeref_or_epoch);
                    timeref = ndi.time.timereference(ndi_element_timeseries_obj, ...
                        et_entry.epoch_clock{1}, timeref_or_epoch, 0);
                end

                [epoch_t0_out, epoch_timeref, msg] = ndi_element_timeseries_obj.session.syncgraph.time_convert(timeref, t0, ...
                    ndi_element_timeseries_obj, ndi.time.clocktype('dev_local_time'));
                [epoch_t1_out, epoch_timeref, msg] = ndi_element_timeseries_obj.session.syncgraph.time_convert(timeref, t1, ...
                    ndi_element_timeseries_obj, ndi.time.clocktype('dev_local_time'));

                if isempty(epoch_timeref)
                    error(['Could not find time mapping (maybe wrong epoch name?): ' msg ]);
                end

                % now we know the epoch to read, finally!

                element_doc = ndi_element_timeseries_obj.load_element_doc();
                sq = ndi.query('depends_on','depends_on','element_id',element_doc.id()) & ...
                    ndi.query('','isa','element_epoch','') & ...
                    ndi.query('epochid.epochid','exact_string',epoch_timeref.epoch,'');
                E = ndi_element_timeseries_obj.session;

                epochdoc = E.database_search(sq);
                if numel(epochdoc)==0
                    error(['Could not find epochdoc for epoch ' epoch_timeref.epoch '.']);
                end
                if numel(epochdoc)>1
                    error(['Found too many epochdoc for epoch ' epoch_timeref.epoch '.']);
                end
                epochdoc = epochdoc{1};

                f = E.database_openbinarydoc(epochdoc,'epoch_binary_data.vhsb');
                [data,t] = vlt.file.custom_file_formats.vhsb_read(f,epoch_t0_out,epoch_t1_out);
                E.database_closebinarydoc(f);

                if isnumeric(t)
                    t = ndi_element_timeseries_obj.session.syncgraph.time_convert(epoch_timeref, t, ...
                        timeref.referent, timeref.clocktype);
                end
            end
        end %readtimeseries()

        %%%%% ndi.element methods

        function [ndi_element_timeseries_obj, epochdoc] = addepoch(ndi_element_timeseries_obj, epochid, epochclock, t0_t1, timepoints, datapoints, epochids)
            % ADDEPOCH - add an epoch to the ndi.element
            %
            % [NDI_ELEMENT_OBJ, EPOCHDOC] = ADDEPOCH(NDI_ELEMENT_TIMESERIES_OBJ, EPOCHID, EPOCHCLOCK, T0_T1, TIMEPOINTS, DATAPOINTS)
            %
            % Registers the data for an epoch with the NDI_ELEMENT_OBJ.
            %
            % Inputs:
            %   NDI_ELEMENT_OBJ: The ndi.element object to modify
            %   EPOCHID:       The name of the epoch to add; should match the name of an epoch from the probe
            %   EPOCHCLOCK:    The epoch clock; must be a single clock type that matches one of the clock types
            %                     of the probe
            %   T0_T1:         The starting time and ending time of the existence of information about the ELEMENT on
            %                     the probe, in units of the epock clock
            %   TIMEPOINTS:    the time points to be added to this epoch; can also be the string 'probe' which means the
            %                     points are read directly from the probe (must be Tx1). Timepoints must be in the units
            %                     of the EPOCHCLOCK.
            %   DATAPOINTS:    the data points that accompany each timepoint (must be TxXxY...), or can be 'probe' to
            %                     read from the probe
            %   EPOCHIDS:      The epoch ids of the original epochs (used in conjunction with a oneepoch document).
            % Outputs:
            %    If a second output is requested in EPOCHDOC, then the DOC is NOT added to the database
            %
            if ndi_element_timeseries_obj.direct
                error(['Cannot add external observations to an ndi.element that is directly based on another ndi.element.']);
            end
            if nargin < 7
                [ndi_element_timeseries_obj, epochdoc] = addepoch@ndi.element(ndi_element_timeseries_obj, epochid, epochclock, t0_t1, 0);
            else
                [ndi_element_timeseries_obj, epochdoc] = addepoch@ndi.element(ndi_element_timeseries_obj, epochid, epochclock, t0_t1, 0, epochids);
            end
            fname = [ndi.common.PathConstants.TempFolder filesep epochdoc.id() '.vhsb'];
            vlt.file.custom_file_formats.vhsb_write(fname,timepoints,datapoints,'use_filelock',0);
            epochdoc = epochdoc.add_file('epoch_binary_data.vhsb',fname);
            if nargout<2
                ndi_element_timeseries_obj.session.database_add(epochdoc);
            end

        end % addepoch()

        function sr = samplerate(ndi_element_timeseries_obj, epoch)
            et = ndi_element_timeseries_obj.epochtableentry(epoch);
            [data, t, timeref] = readtimeseries(ndi_element_timeseries_obj, epoch, et.t0_t1{1}(1), et.t0_t1{1}(1)+0.5);
            sr = 1/median(diff(t));
        end % samplerate()

        function ndi_document_obj = newdocument(ndi_element_timeseries_obj, varargin)
            % NEWDOCUMENT - Todo: need docs here
            ndi_document_obj = newdocument@ndi.element(ndi_element_timeseries_obj, varargin{:});
        end % newdocument

        function sq = searchquery(ndi_element_timeseries_obj, varargin)
            % SEARCHQUERY - Todo: need docs here
            sq = searchquery@ndi.element(ndi_element_timeseries_obj, varargin{:});
        end % searchquery

    end % methods
end % classdef
