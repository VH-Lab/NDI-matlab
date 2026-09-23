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

    methods (Static)
        function neurons = addMultiple(S, underlying_element, specs, options)
            % ADDMULTIPLE - create many timeseries elements with epochs in batched database writes
            %
            % NEURONS = ndi.element.timeseries.addMultiple(S, UNDERLYING_ELEMENT, SPECS, ...)
            %
            % Creates many ndi.element.timeseries elements (by default ndi.neuron) that share a
            % common UNDERLYING_ELEMENT (e.g. a probe), each with one or more epochs of time series
            % data, while minimizing the number of database round-trips. This is much faster than
            % constructing each element and calling ADDEPOCH per epoch, which performs a database
            % search and a separate database write for every epoch of every element.
            %
            % Inputs:
            %   S                 - the ndi.session
            %   UNDERLYING_ELEMENT- the ndi.element (e.g. probe) the new elements are built on; it
            %                         supplies the subject and underlying_element dependencies
            %   SPECS             - a struct array, one entry per element to create, with fields:
            %       .name             (char)   the element name
            %       .reference        (double) the element reference number
            %       .type             (char)   the element type (optional; default 'spikes')
            %       .epochs           a struct array (one per epoch) with fields:
            %                            .epoch_id    (char) the epoch id
            %                            .epoch_clock (char or ndi.time.clocktype) the epoch clock
            %                            .t0_t1       [t0 t1] interval in the epoch clock's units
            %                            .timepoints  (Tx1) the time points (e.g. spike times)
            %                            .datapoints  (TxXx...) data accompanying each time point
            %       .extra_documents  (optional) a cell array of ndi.document objects to commit in
            %                            the same batch as this element's epochs; each one's
            %                            'element_id' dependency is set to the new element. Use this
            %                            for e.g. a 'neuron_extracellular' document per neuron.
            %
            % This function takes name/value pairs that modify its operation:
            % ---------------------------------------------------------------------------------
            % | Parameter (default)        | Description                                        |
            % |----------------------------|----------------------------------------------------|
            % | element_class ('ndi.neuron')| Class of element to create. Must accept the        |
            % |                            |   (SESSION, DOCUMENT) constructor form.            |
            % | chunksize (100)            | Number of elements to build and commit per batch.  |
            % |                            |   Bounds peak memory and temporary .vhsb files.    |
            % | progressbar (false)        | Show an ndi.gui.component.ProgressBarWindow.       |
            % | verbose (false)            | 0/1 report progress to the command line.          |
            % ---------------------------------------------------------------------------------
            %
            % Output (optional): NEURONS is an array of the created element objects (class
            % element_class). It is only constructed if an output is requested; the importer calls
            % this as a statement to avoid the per-element construction cost.
            %
            % See also: NDI.ELEMENT.TIMESERIES/ADDEPOCH, NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE
            arguments
                S (1,1) ndi.session
                underlying_element (1,1) ndi.element
                specs struct
                options.element_class (1,:) char = 'ndi.neuron'
                options.chunksize (1,1) double {mustBePositive} = 100
                options.progressbar (1,1) logical = false
                options.verbose (1,1) logical = false
            end

            neurons = [];
            n = numel(specs);
            if n==0, return; end;

            subject_id = underlying_element.subject_id;
            underlying_id = underlying_element.id();
            tempfolder = ndi.common.PathConstants.TempFolder;
            session_id = S.id();

            % optional progress bar
            usebar = options.progressbar;
            baruuid = '';
            if usebar,
                try
                    progBar = ndi.gui.component.ProgressBarWindow('Import Kilosort','GrabMostRecent',true);
                    baruuid = did.ido.unique_id();
                    progBar.addBar('Label','Creating neurons','Tag',baruuid,'Auto',true);
                catch
                    usebar = false;
                end;
            end;

            buildObjects = nargout>=1;
            neuron_cell = cell(1,n);

            idx = 0;
            while idx < n,
                chunk = (idx+1):min(idx+options.chunksize, n);
                elemdocs = cell(1,numel(chunk));
                depdocs = {}; % epoch + extra documents for this chunk (depend on the elements)

                for k=1:numel(chunk),
                    i = chunk(k);
                    sp = specs(i);
                    etype = 'spikes';
                    if isfield(sp,'type') && ~isempty(sp.type), etype = sp.type; end;

                    edoc = ndi.document('element','base.session_id', session_id, ...
                        'element.ndi_element_class', options.element_class, ...
                        'element.name', sp.name, ...
                        'element.reference', sp.reference, ...
                        'element.type', etype, ...
                        'element.direct', 0);
                    edoc = edoc.set_dependency_value('underlying_element_id', underlying_id);
                    edoc = edoc.set_dependency_value('subject_id', subject_id);
                    elem_id = edoc.id();
                    elemdocs{k} = edoc;

                    % epoch documents (mirror ndi.element.timeseries/addepoch, but without the
                    % per-epoch database search: we already know the element id)
                    if isfield(sp,'epochs') && ~isempty(sp.epochs),
                        eps = sp.epochs;
                        for j=1:numel(eps),
                            ep = eps(j);
                            if isa(ep.epoch_clock,'ndi.time.clocktype'),
                                clkstr = ep.epoch_clock.ndi_clocktype2char();
                            else,
                                clkstr = ep.epoch_clock;
                            end;
                            t0t1 = ep.t0_t1;
                            if numel(t0t1)==2, t0t1 = vlt.data.colvec(t0t1); end;
                            epdoc = ndi.document('element_epoch','base.session_id', session_id, ...
                                'element_epoch.epoch_clock', clkstr, ...
                                'element_epoch.t0_t1', t0t1, ...
                                'epochid.epochid', ep.epoch_id);
                            epdoc = epdoc.set_dependency_value('element_id', elem_id);
                            fname = [tempfolder filesep epdoc.id() '.vhsb'];
                            vlt.file.custom_file_formats.vhsb_write(fname, ...
                                vlt.data.colvec(ep.timepoints), ep.datapoints, 'use_filelock',0);
                            epdoc = epdoc.add_file('epoch_binary_data.vhsb', fname);
                            depdocs{end+1} = epdoc; %#ok<AGROW>
                        end;
                    end;

                    % extra documents (e.g. neuron_extracellular); stamp element_id
                    if isfield(sp,'extra_documents') && ~isempty(sp.extra_documents),
                        ex = sp.extra_documents;
                        if ~iscell(ex), ex = {ex}; end;
                        for j=1:numel(ex),
                            depdocs{end+1} = ex{j}.set_dependency_value('element_id', elem_id); %#ok<AGROW>
                        end;
                    end;

                    if buildObjects,
                        neuron_cell{i} = feval(options.element_class, S, edoc);
                    end;
                    if options.verbose,
                        disp(['  Built ' sp.name '.']);
                    end;
                end;

                % commit: the elements first, then everything that depends on them
                S.database_add(elemdocs);
                if ~isempty(depdocs),
                    S.database_add(depdocs);
                end;

                idx = chunk(end);
                if usebar,
                    progBar.updateBar(baruuid, idx/n);
                end;
            end;

            if usebar,
                progBar.updateBar(baruuid, 1);
            end;

            if buildObjects,
                neurons = neuron_cell{1};
                for i=2:n,
                    neurons(i) = neuron_cell{i};
                end;
            end;
        end % addMultiple()
    end % methods (Static)
end % classdef
