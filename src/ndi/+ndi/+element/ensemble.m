classdef ensemble < ndi.element.timeseries
    % ndi.element.ensemble - a spiking-neuron ensemble as a timeseries element
    %
    % An ndi.element.ensemble is an ndi.element.timeseries (type 'ensemble') that
    % is built on a probe (its underlying element) and represents the joint
    % spiking activity of the neurons recorded on that probe. Each epoch stores a
    % marked point process: every spike of every neuron, sorted by time, with a
    % "mark" that says which neuron fired it.
    %
    % readtimeseries therefore returns, for a requested time window,
    %
    %    [NEURONINDEX, SPIKETIME] = readtimeseries(OBJ, TIMEREF_OR_EPOCH, T0, T1)
    %
    % where SPIKETIME(k) is the time of the k-th spike (in the window) and
    % NEURONINDEX(k) is the 1-based column index of the neuron that fired it.
    % Because the data are stored with the standard element-timeseries binary
    % (vhsb), reads are windowed and the times come back in the element's clock
    % (inherited from the underlying probe).
    %
    % The mapping from a column index to the actual neuron is stored PER EPOCH
    % (the set of recorded neurons may change from epoch to epoch): each epoch has
    % an 'ensemble' ndi.document that depends on that epoch's element_epoch
    % document and lists the neuron element ids (in column order) and their names.
    % Recover the mapping with the neuronIds / neuronNames / neurons methods -- do
    % not read the document directly.
    %
    % Construction:
    %    OBJ = ndi.element.ensemble(S, NAME, REFERENCE, PROBE) - build
    %    OBJ = ndi.element.ensemble(S, DOC_OR_ID)                          - load
    %
    % See also: ndi.element.timeseries, ndi.fun.ensemble.create,
    %   ndi.fun.ensemble.read, ndi.fun.ensemble.plot

    methods
        function obj = ensemble(varargin)
            % ENSEMBLE - create an ndi.element.ensemble object
            %
            % OBJ = ndi.element.ensemble(S, NAME, REFERENCE, PROBE)
            %   builds an ensemble element of type 'ensemble' with PROBE as its
            %   underlying element (the subject is taken from PROBE). If an element
            %   with the same name/reference already exists in S it is loaded
            %   rather than duplicated.
            %
            % OBJ = ndi.element.ensemble(S, DOC_OR_ID)
            %   loads an existing ensemble element from its ndi.document (or id).
            %
            if numel(varargin) >= 4
                S = varargin{1};
                name = varargin{2};
                reference = varargin{3};
                underlying = varargin{4};
                % The subject is derived from the underlying element; do NOT pass
                % a subject_id (a 7th argument), or the base constructor warns
                % that it is ignoring it.
                args = {S, name, reference, 'ensemble', underlying, 0};
            else
                args = varargin; % load form (S, doc/id) or pass-through
            end
            obj = obj@ndi.element.timeseries(args{:});
        end % ensemble()

        function [obj, epochdoc, mapdoc] = addEnsembleEpoch(obj, epochid, epochclock, ...
                t0_t1, neuron_ids, neuron_names, spike_rows, options)
            % ADDENSEMBLEEPOCH - add one epoch of ensemble activity
            %
            % [OBJ, EPOCHDOC, MAPDOC] = ADDENSEMBLEEPOCH(OBJ, EPOCHID, EPOCHCLOCK,
            %    T0_T1, NEURON_IDS, NEURON_NAMES, SPIKE_ROWS, ...)
            %
            % Registers an epoch whose activity is the spike trains SPIKE_ROWS (a
            % 1-by-N cell array; SPIKE_ROWS{k} is a vector of spike times for the
            % neuron whose element id is NEURON_IDS{k} and whose name is
            % NEURON_NAMES{k}). The spikes are flattened into a single time-sorted
            % marked point process (time, neuron column index) and stored with the
            % standard element-timeseries binary, and a per-epoch 'ensemble' map
            % document (depending on the new element_epoch document) records the
            % NEURON_IDS / NEURON_NAMES for this epoch's columns.
            %
            % EPOCHCLOCK is an ndi.time.clocktype (or its name) for the spike
            % times; T0_T1 is the [t0 t1] extent of the epoch in that clock.
            %
            % Options (name/value):
            %   value_type ('spiketimes')  | stored in the map document.
            %   value_description ('')     | stored in the map document.
            %   ensemble_name ('')         | stored in the map document.
            %   add_to_database (true)     | if true, EPOCHDOC and MAPDOC are added
            %                              |   to the database; if false they are
            %                              |   returned unadded.
            arguments
                obj
                epochid (1,:) char
                epochclock
                t0_t1 (1,2) double
                neuron_ids cell
                neuron_names cell
                spike_rows cell
                options.value_type (1,:) char = 'spiketimes'
                options.value_description (1,:) char = ''
                options.ensemble_name (1,:) char = ''
                options.add_to_database (1,1) logical = true
            end

            if ~isa(epochclock,'ndi.time.clocktype')
                epochclock = ndi.time.clocktype(epochclock);
            end
            if numel(neuron_ids)~=numel(spike_rows) || numel(neuron_names)~=numel(neuron_ids)
                error('ndi:element:ensemble:sizeMismatch', ...
                    ['NEURON_IDS, NEURON_NAMES, and SPIKE_ROWS must all have the ' ...
                    'same number of elements.']);
            end

            % flatten the per-neuron spike trains into a time-sorted marked point
            % process: times of every spike, and the neuron column index of each
            N = numel(spike_rows);
            times = [];
            colindex = [];
            for k = 1:N
                v = spike_rows{k}(:).';
                times = [times, v]; %#ok<AGROW>
                colindex = [colindex, k*ones(1,numel(v))]; %#ok<AGROW>
            end
            [times, order] = sort(times);
            colindex = colindex(order);

            % store the epoch data via the inherited element-timeseries addepoch
            % (capturing epochdoc => it is returned but NOT added to the database)
            [obj, epochdoc] = obj.addepoch(epochid, epochclock, t0_t1, ...
                times(:), colindex(:));

            % build the per-epoch neuron map document
            mapdoc = obj.buildMapDoc(epochid, epochclock, epochdoc, ...
                neuron_ids, neuron_names, options);

            if options.add_to_database
                obj.session.database_add(epochdoc);
                obj.session.database_add(mapdoc);
                % A new epoch/element was added. Clear the cached epochtable and
                % the cached syncgraph so both are rebuilt from the database on
                % the next epochtable/readtimeseries; otherwise a read in the same
                % session cannot find this newly added element's epoch.
                obj = obj.resetepochtable();
                obj.session.syncgraph.remove_cached_graphinfo();
            end
        end % addEnsembleEpoch()

        function d = epochEnsembleDoc(obj, epoch)
            % EPOCHENSEMBLEDOC - the 'ensemble' map document for one epoch
            %
            % D = EPOCHENSEMBLEDOC(OBJ, EPOCH)
            %
            % Returns the 'ensemble' ndi.document that holds the neuron column map
            % for EPOCH (an epoch id or index). Errors if none (or more than one)
            % is found.
            epochidstr = obj.epochid(epoch);
            sq = ndi.query('','isa','ensemble','') & ...
                ndi.query('','depends_on','element_id', obj.id()) & ...
                ndi.query('epochid.epochid','exact_string', epochidstr, '');
            docs = obj.session.database_search(sq);
            if isempty(docs)
                error('ndi:element:ensemble:noMap', ...
                    'No ensemble map document was found for epoch ''%s''.', epochidstr);
            elseif numel(docs)>1
                error('ndi:element:ensemble:tooManyMaps', ...
                    'More than one ensemble map document was found for epoch ''%s''.', epochidstr);
            end
            d = docs{1};
        end % epochEnsembleDoc()

        function ids = neuronIds(obj, epoch)
            % NEURONIDS - the neuron element ids for an epoch, in column order
            %
            % IDS = NEURONIDS(OBJ, EPOCH)
            %
            % Returns a 1-by-N cell array of the neuron element document ids for
            % EPOCH. Column index i of readtimeseries corresponds to IDS{i}.
            d = obj.epochEnsembleDoc(epoch);
            ids = d.dependency_value_n('neuron_id','ErrorIfNotFound',0);
            ids = ids(:).';
        end % neuronIds()

        function names = neuronNames(obj, epoch)
            % NEURONNAMES - the neuron names for an epoch, in column order
            %
            % NAMES = NEURONNAMES(OBJ, EPOCH)
            %
            % Returns a 1-by-N cell array of the neuron names for EPOCH (the lines
            % of the map document's neuron_names.txt file).
            d = obj.epochEnsembleDoc(epoch);
            tempfile = ndi.database.fun.copydocfile2temp(d, obj.session, ...
                'neuron_names.txt', '.txt');
            cleanup = onCleanup(@() obj.deletefile(tempfile)); %#ok<NASGU>
            names = obj.readlines(tempfile);
        end % neuronNames()

        function nrns = neurons(obj, epoch)
            % NEURONS - the neuron element objects for an epoch, in column order
            %
            % NRNS = NEURONS(OBJ, EPOCH)
            %
            % Returns a 1-by-N cell array of the ndi.element objects that make up
            % the ensemble for EPOCH.
            ids = obj.neuronIds(epoch);
            nrns = cell(1, numel(ids));
            for i = 1:numel(ids)
                nrns{i} = ndi.database.fun.ndi_document2ndi_object(ids{i}, obj.session);
            end
        end % neurons()

        function [M, ids] = spikeMatrix(obj, epoch)
            % SPIKEMATRIX - reconstruct the neuron-by-spike sparse matrix for an epoch
            %
            % [M, IDS] = SPIKEMATRIX(OBJ, EPOCH)
            %
            % Reads the whole epoch and returns M, an N-neurons-by-Smax sparse
            % matrix where M(i,n) is the time of the n-th spike of neuron i, and
            % IDS, the 1-by-N neuron element ids for the rows (same as
            % NEURONIDS(OBJ, EPOCH)). This is the export form (see also
            % ndi.util.writeSparse).
            epochidstr = obj.epochid(epoch);
            ids = obj.neuronIds(epochidstr);
            N = numel(ids);
            [colindex, times] = obj.readtimeseries(epochidstr, -Inf, Inf);
            colindex = round(colindex(:).');
            times = times(:).';
            Smax = 0;
            for c = 1:N
                Smax = max(Smax, sum(colindex==c));
            end
            M = sparse(N, max(Smax,1));
            for c = 1:N
                sc = times(colindex==c);
                if ~isempty(sc)
                    M(c,1:numel(sc)) = sc;
                end
            end
        end % spikeMatrix()

    end % methods

    methods (Access=private)
        function mapdoc = buildMapDoc(obj, epochid, epochclock, epochdoc, ...
                neuron_ids, neuron_names, options)
            % build (but do not add) the per-epoch 'ensemble' map document
            if isa(epochclock,'ndi.time.clocktype')
                clockname = epochclock.type;
            else
                clockname = char(epochclock);
            end

            names_tempfile = [ndi.file.temp_name() '.txt'];
            fid = fopen(names_tempfile, 'w');
            if fid<0
                error('ndi:element:ensemble:cannotOpen', ...
                    'Could not open a temporary file for the neuron names.');
            end
            for i = 1:numel(neuron_names)
                fprintf(fid, '%s\n', neuron_names{i});
            end
            fclose(fid);

            mapdoc = obj.session.newdocument('ensemble', ...
                'ensemble.ensemble_name', options.ensemble_name, ...
                'ensemble.value_type', options.value_type, ...
                'ensemble.value_description', options.value_description, ...
                'ensemble.num_neurons', numel(neuron_ids), ...
                'ensemble.clocktype', clockname, ...
                'epochid.epochid', epochid, ...
                'app.name', 'ndi.element.ensemble');
            % These dependencies are declared in the 'ensemble' definition, so a
            % missing one (default ErrorIfNotFound=1 raises) signals a genuine
            % problem -- a wrong definition or a stale in-memory definition cache
            % that must be cleared -- rather than something to paper over.
            mapdoc = mapdoc.set_dependency_value('element_id', obj.id());
            mapdoc = mapdoc.set_dependency_value('element_epoch_id', epochdoc.id());
            for i = 1:numel(neuron_ids)
                mapdoc = mapdoc.add_dependency_value_n('neuron_id', neuron_ids{i});
            end
            mapdoc = mapdoc.add_file('neuron_names.txt', names_tempfile);
        end % buildMapDoc()
    end % private methods

    methods (Static, Access=private)
        function names = readlines(filename)
            txt = fileread(filename);
            if isempty(txt)
                names = {};
                return;
            end
            lines = regexp(txt, '\r\n|\r|\n', 'split');
            if ~isempty(lines) && isempty(lines{end})
                lines(end) = [];
            end
            names = lines(:).';
        end % readlines()

        function deletefile(filename)
            if exist(filename,'file')
                delete(filename);
            end
        end % deletefile()
    end % static private methods

end % classdef
