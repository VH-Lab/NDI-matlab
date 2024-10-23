classdef spikesorter < ndi.app & ndi.app.appdoc

    properties (SetAccess=protected,GetAccess=public)
    end % properties

    methods

        function ndi_app_spikesorter_obj =spikesorter(varargin)
            % NDI.APP.spikesorter - an app to sort spikewaves found in sessions
            %
            % NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
            %
            % Creates a new NDI_APP_spikesorter object that can operate on
            % NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.
            %
            session = [];
            name = 'ndi_app_spikesorter';
            if numel(varargin)>0,
                session = varargin{1};
            end

            ndi_app_spikesorter_obj = ndi_app_spikesorter_obj@ndi.app(session, name);
            % initiate app doc
            ndi_app_spikesorter_obj = ndi_app_spikesorter_obj@ndi.app.appdoc(...
                {'sorting_parameters','spike_clusters'},...
                {'sorting_parameters','spike_clusters'},...
                session);
        end % ndi.app.spikesorter() creator

        function sorting_parameters_struct = check_sorting_parameters(ndi_app_spikesorter_obj, sorting_parameters_struct)
            % CHECK_SORTING_PARAMETERS - check sorting parameters for validity
            %
            % SORTING_PARAMETERS_STRUCT = CHECK_SORTING_PARAMETERS(NDI_APP_SPIKESORTER_OBJ, SORTING_PARAMETERS_STRUCT)
            %
            % Given a sorting parameters structure (see help ndi.app.spikesorter/appdoc_description), check that the
            % parameters are provided and are in appropriate ranges.
            %
            % interpolation
            interpolation = 1;
            if isfield(sorting_parameters_struct,'interpolation'),
                interpolation = max(1,round(sorting_parameters_struct.interpolation));
                interpolation = min(interpolation,10); % no interpolation bigger than 10; that's crazy
            else,
                error(['Expected sorting parameters field ''interpolation'' is missing.']);
            end;
        end; % check_sorting_parameters

        function [waveforms, waveformparams, spiketimes, epochinfo, extraction_params_doc, waveform_docs] = loadwaveforms(ndi_app_spikesorter_obj, ndi_timeseries_obj, extraction_name)
            % LOADWAVEFORMS - load extracted spike waveforms for an ndi_timeseries_obj
            %
            % [WAVEFORMS, WAVEFORMPARAMS, SPIKETIMES, EPOCHINFO, EXTRACTION_PARAMS_DOC, WAVEFORM_DOCS] = LOADWAVEFORMS(...
            %         NDI_APP_SPIKESORTER_OBJ, NDI_TIMESERIES_OBJ,EXTRACTION_NAME)
            %
            % Loads extracted spike WAVEFORMS from an NDI_TIMESERIERS_OBJ with extraction name EXTRACTION_NAME.
            %
            % WAVEFORMS is a NumSamples x NumChannels x NumSpikes representation of each spike waveform.
            % WAVEFORMPARAMS is the set of waveform parameters from ndi.app.spikeextractor that includes information
            %    such as the sample dimensions and the sampling rate of the underlying data.
            %    See help ndi.app.spikeextractor.appdoc_description.
            % SPIKTIMES is time of each spike waveform.
            % EPOCHINFO - a structure with fields EpochStartSamples that indicates the waveform sample that begins each new
            %    epoch from the NDI_TIMESERIES_OBJ and EpochNames that is a cell array of the epoch ID of each epoch.
            % EXTRACTION_PARAMS_DOC is the ndi.document for the extraction parameters.
            % WAVEFORM_DOCS is a cell array of ndi.documents for each extracted spike waveform document.

            waveforms = [];
            spiketimes = [];
            waveformparams = [];
            epochinfo.EpochStartSamples = [];
            epochinfo.EpochNames = {};
            waveform_docs = {};

            e = ndi.app.spikeextractor(ndi_app_spikesorter_obj.session); % new spikeextractor app

            extraction_params_doc = e.loaddata_appdoc('extraction_parameters', extraction_name);

            if isempty(extraction_params_doc),
                error(['Could not load extraction parameters document with name ' extraction_name '.']);
            end;

            et = ndi_timeseries_obj.epochtable();

            sample_counter = 0;

            for i=1:numel(et),
                epochinfo.EpochStartSamples(end+1) = sample_counter + 1;
                epochinfo.EpochNames{end+1} = et(i).epoch_id;
                [waveshere, waveformparams, spiketimes_here, waveform_docs{end+1}]=e.loaddata_appdoc('spikewaves',...
                    ndi_timeseries_obj, et(i).epoch_id, extraction_name);
                if isempty(waveforms),
                    waveforms = waveshere;
                else,
                    waveforms = cat(3,waveforms,waveshere);
                end;
                if isempty(spiketimes),
                    spiketimes = spiketimes_here(:);
                else,
                    spiketimes = cat(1,spiketimes,spiketimes_here(:));
                end;
                sample_counter = sample_counter + size(waveshere,3);
            end;
        end; % loadwaveforms

        function spike_cluster_doc = spike_sort(ndi_app_spikesorter_obj, ndi_timeseries_obj, extraction_name, sorting_parameters_name, redo)
            % SPIKE_SORT - method that sorts spikes from specific probes in session to ndi_doc
            %
            % SPIKE_CLUSTER_DOC = SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
            %%%%%%%%%%%%%%
            % SORT_NAME name given to save sort to ndi_doc

            %%% Step 1: Get our documents, see if we have any work to do or if it is all done, and generally set up
            if exist('redo','var') == 0
                redo = 0;
            end

            % Step 1a: get our sorting_parameters document, bail out if we can't get it

            sorting_parameters_doc = ndi_app_spikesorter_obj.find_appdoc('sorting_parameters', sorting_parameters_name);
            if numel(sorting_parameters_doc)==0,
                error(['No spike sorting parameters document document with name ' sorting_parameters_name ' was found.']);
            elseif numel(sorting_parameters_doc)>1,
                error(['Too many spike sorting parameters document document with name ' sorting_parameters_name ' were found. Don''t know what to do. Bailing out.']);
            else, % we have the number we need
                sorting_parameters_doc = sorting_parameters_doc{1};
            end;

            sorting_parameters_struct = ndi_app_spikesorter_obj.check_sorting_parameters(sorting_parameters_doc.document_properties.sorting_parameters);

            % Step 1b: do we already have a cluster document? If so, are we re-doing it or just returning it and being done?

            spike_cluster_doc = ndi_app_spikesorter_obj.find_appdoc('spike_clusters', ndi_timeseries_obj, extraction_name,...
                sorting_parameters_name);

            if numel(spike_cluster_doc)==1 & ~redo,
                % probably should check to see if there are new epochs extracted; if so, it's not really up-to-date
                % we are done
                spike_cluster_doc = spike_cluster_doc{1};
                return;
            elseif redo, % if we are re-doing, destroy the old docs
                ndi_app_spikesorter_obj.session.database_rm(spike_cluster_doc);
                spike_cluster_doc = {};
            end;

            % Step 1c: Now that we know we are continuing, we need to gather our waveforms.

            [waveforms, waveformparameters, spiketimes, epochinfo, extract_doc, waveform_docs] = ...
                ndi_app_spikesorter_obj.loadwaveforms(ndi_timeseries_obj, extraction_name);
            extract_doc = extract_doc{1};

            %%% Step 2: do the sorting according to instructions

            wavesamples = waveformparameters.S0:waveformparameters.S1;
            if sorting_parameters_struct.interpolation > 1,
                waveforms = permute(waveforms,[3 1 2]);
                [waveforms, wavesamples] = vlt.neuro.spikesorting.oversamplespikes(waveforms, sorting_parameters_struct.interpolation,wavesamples);
                waveform_sign = -1*extract_doc.document_properties.spike_extraction_parameters.threshold_sign;
                waveforms = waveform_sign*centerspikes_neg(waveform_sign*waveforms,10);
                waveforms = permute(waveforms,[2 3 1]);
            end;

            if sorting_parameters_struct.graphical_mode, % Are we graphical? Then, pop-up the editor.
                [clusterids, clusterinfo] = vlt.neuro.spikesorting.cluster_spikewaves_gui('waves', waveforms, ...
                    'waveparameters', waveformparameters, ...
                    'clusterids', [], 'wavetimes', [], ...
                    'EpochStartSamples', epochinfo.EpochStartSamples, 'EpochNames', epochinfo.EpochNames,...
                    'spikewaves2NpointfeatureSampleList', [floor(numel(wavesamples)/2) round( (5/6) * numel(wavesamples))]);
            else, % Otherwise, we are automatically sorting
                features = vlt.neuro.spikesorting.spikewaves2pca(waveforms, sorting_parameters_struct.num_pca_features);
                disp('KlustarinKwikly... (running KlustaKwik)');
                [clusterids,numclusters] = klustakwik_cluster(features, ...
                    sorting_parameters_struct.min_clusters, sorting_parameters_struct.max_clusters, ...
                    sorting_parameters_struct.num_start, 0);
                clusterinfo = vlt.neuro.spikesorting.cluster_initializeclusterinfo(clusterids, waveforms, epochinfo);
                disp('Done clustering.');
            end;

            % Create spike_clusters ndi_doc

            spike_clusters.epoch_info = epochinfo;
            spike_clusters.clusterinfo = clusterinfo;
            spike_clusters.waveform_sample_times = vlt.data.colvec(wavesamples);
            spike_cluster_doc = ndi_app_spikesorter_obj.session.newdocument('spike_clusters', ...
                'spike_clusters', spike_clusters) ...
                + ndi_app_spikesorter_obj.newdocument();
            spike_cluster_doc = spike_cluster_doc.set_dependency_value('element_id', ndi_timeseries_obj.id());
            spike_cluster_doc = spike_cluster_doc.set_dependency_value('sorting_parameters_id',sorting_parameters_doc.id());
            spike_cluster_doc = spike_cluster_doc.set_dependency_value('extraction_parameters_id',extract_doc.id());
            for i=1:numel(waveform_docs),
                spike_cluster_doc = spike_cluster_doc.add_dependency_value_n('spikewaves_doc_id',waveform_docs{i}.id());
            end;
            [spike_cluster_binarydoc,spike_cluster_binarydoc_filename] = ndi.file.temp_fid();
            fwrite(spike_cluster_binarydoc,uint16(clusterids),'uint16');
            fclose(spike_cluster_binarydoc);
            spike_cluster_doc = spike_cluster_doc.add_file('spike_cluster.bin',spike_cluster_binarydoc_filename);

            % Add doc to database

            ndi_app_spikesorter_obj.session.database_add(spike_cluster_doc);

        end % spike_sort()

        function clusters2neurons(ndi_app_spikesorter_obj, ndi_timeseries_obj, sorting_parameters_name, extraction_parameters_name, redo)
            % CLUSTERS2NEURONS - create ndi.neuron objects from spike clusterings
            %
            % CLUSTERS2NEURONS(NDI_APP_SPIKESORTER_OBJ, NDI_TIMESERIES_OBJ, SORTING_PARAMETER_NAME, EXTRACTION_PARAMETERS_NAME, REDO)
            %
            % Generates ndi.neuron objects for each spike cluster represented in the
            %
            if ~exist('redo','var'),
                redo = 0;
            end;

            [clusterids,spike_clusters_doc] = ndi_app_spikesorter_obj.loaddata_appdoc('spike_clusters',ndi_timeseries_obj,...
                extraction_parameters_name, sorting_parameters_name);

            q_E = ndi.query(ndi_app_spikesorter_obj.session.searchquery());
            q_n = ndi.query('','isa','neuron_extracellular','') & ndi.query('','depends_on','spike_clusters_id',spike_clusters_doc.id());
            anyneurons = ndi_app_spikesorter_obj.session.database_search(q_n);
            if ~redo & ~isempty(anyneurons),
                return; % we are done
            elseif redo & ~isempty(anyneurons),
                for n=1:numel(anyneurons),
                    e_here = anyneurons{n}.dependency_value('element_id');
                    q_here = ndi.query('base.id','exact_string',e_here,'');
                    if n==1,
                        q_ne = q_here;
                    else,
                        q_ne = q_ne | q_here;
                    end;
                end;
                anyneuronelements = ndi_app_spikesorter_obj.session.database_search(q_ne);
                ndi_app_spikesorter_obj.session.database_rm(anyneuronelements);
            end;

            [waveforms, waveformparams, spiketimes, epochinfo, extraction_params_doc, waveform_docs] = ...
                ndi_app_spikesorter_obj.loadwaveforms(ndi_timeseries_obj, extraction_parameters_name);
            et = ndi_timeseries_obj.epochtable();

            include = [];
            clusterinfo  = spike_clusters_doc.document_properties.spike_clusters.clusterinfo;
            for n=1:numel(clusterinfo),
                if ~any(strcmpi(clusterinfo(n).qualitylabel, {'Unselected', 'Not useable'})),
                    include(end+1) = n;
                end;
            end;
            ndidocapp = ndi_app_spikesorter_obj.newdocument();
            appstruct = ndidocapp.document_properties.app;
            EpochStartStopSamples = [ epochinfo.EpochStartSamples numel(spiketimes)-1 ];

            for n=1:numel(include),
                clusternum = include(n);
                neuron_extracellular.number_of_samples_per_channel = size(clusterinfo(clusternum).meanshape,1);
                neuron_extracellular.number_of_channels = size(clusterinfo(clusternum).meanshape,2);
                neuron_extracellular.mean_waveform = clusterinfo(clusternum).meanshape;
                neuron_extracellular.waveform_sample_times = spike_clusters_doc.document_properties.spike_clusters.waveform_sample_times;
                neuron_extracellular.cluster_index = clusternum;
                switch lower(clusterinfo(clusternum).qualitylabel),
                    case lower('Unselected'),
                        value = -1;
                    case lower('Not useable'),
                        value = 5;
                    case lower('Multi-unit'),
                        value = 3;
                    case lower('Good'),
                        value = 2;
                    case lower('Excellent'),
                        value = 1;
                    otherwise,
                        value = -1;
                end; % switch
                neuron_extracellular.quality_number = value;
                neuron_extracellular.quality_label = clusterinfo(clusternum).qualitylabel;
                if value >0 & value <=4, % only add reasonable neurons
                    element_neuron = ndi.neuron(ndi_app_spikesorter_obj.session, ...
                        [ndi_timeseries_obj.name '_' num2str(clusternum)], ndi_timeseries_obj.reference, 'spikes', ...
                        ndi_timeseries_obj, 0, []);
                    neuron_doc = ndi.document('neuron_extracellular','neuron_extracellular',neuron_extracellular,'app',appstruct,'base.session_id',ndi_app_spikesorter_obj.session.id());
                    neuron_doc = neuron_doc.set_dependency_value('element_id',element_neuron.id());
                    neuron_doc = neuron_doc.set_dependency_value('spike_clusters_id',spike_clusters_doc.id())
                    ndi_app_spikesorter_obj.session.database_add(neuron_doc);
                    epoch_start_index = find(strcmp(clusterinfo(clusternum).EpochStart, {et.epoch_id}));
                    epoch_stop_index = find(strcmp(clusterinfo(clusternum).EpochStop, {et.epoch_id}));
                    spike_indexes = find(clusterids==clusternum);
                    for j=epoch_start_index:epoch_stop_index,
                        local_sample_start = EpochStartStopSamples(j);
                        local_sample_stop = EpochStartStopSamples(j+1) - 1;
                        spike_indexes_here = spike_indexes(find(spike_indexes >= local_sample_start & spike_indexes <= local_sample_stop));
                        spike_times_here = spiketimes(spike_indexes_here);
                        element_neuron.addepoch(et(j).epoch_id, ndi.time.clocktype('dev_local_time'), ...
                            et(j).t0_t1{1}, spike_times_here(:), ones(size(spike_times_here(:))));
                    end;
                end;
            end % for n
        end; %  clusters2neurons()

        %%%%%%%%%%%%%%%%%%%% FUNCTIONS THAT OVERRIDE NDI.APP.APPDOC:

        function doc = struct2doc(ndi_app_spikesorter_obj, appdoc_type, appdoc_struct, varargin)
            % STRUCT2DOC - create an ndi.document from an input structure and input parameters
            %
            % DOC = STRUCT2DOC(NDI_APP_SPIKESORTER_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
            %
            % For ndi.app.spikesorter, one can use an APPDOC_TYPE of the following:
            % APPDOC_TYPE                 | Description
            % ----------------------------------------------------------------------------------------------
            % 'sorting_parameters'  | A document that describes the parameters to be used for sorting
            %
            %
            % See APPDOC_DESCRIPTION for a list of the parameters.
            %
            if strcmpi(appdoc_type,'sorting_parameters'),
                if numel(varargin)<1,
                    error(['Needs an additional argument describing the sorting parameters name']);
                end;
                if ~ischar(varargin{1}),
                    error(['sorting parameters name must be a character string.']);
                end;
                sorting_name = varargin{1};
                doc = ndi.document('sorting_parameters',...
                    'sorting_parameters',appdoc_struct) + ...
                    ndi_app_spikesorter_obj.newdocument() + ...
                    ndi.document('base','base.name',sorting_name);
            elseif strcmpi(appdoc_type,'spike_clusters'),
                error(['spike_clusters documents are created internally.']);
            else
                error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
            end
        end %struct2doc()

        function [b,errormsg] = isvalid_appdoc_struct(ndi_app_spikesorter_obj, appdoc_type, appdoc_struct)
            % ISVALID_APPDOC_STRUCT - is an input structure a valid descriptor for an APPDOC?
            %
            % [B,ERRORMSG] = ISVALID_APPDOC_STRUCT(ndi.app.spikeextractor_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
            %
            % Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
            % ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
            %
            % For ndi_app_spikesorter, one can use an APPDOC_TYPE of the following:
            % APPDOC_TYPE               | Description
            % ----------------------------------------------------------------------------------------------
            % 'sorting_parameters'   | A document that describes the parameters to be used for sorting
            % 'spike_clusters'       | A document that describes the

            errormsg = '';
            if strcmpi(appdoc_type,'sorting_parameters')
                sorting_parameters = appdoc_struct;
                % check parameters here
                fields_needed = {'graphical_mode', 'num_pca_features', 'interpolation','min_clusters','max_clusters','num_start'};
                sizes_needed = {[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]}; % all single numbers, size should be 1x1
                [b,errormsg] = vlt.data.hasAllFields(sorting_parameters, fields_needed, sizes_needed);
            elseif strcmpi(appdoc_type,'spike_clusters')
                spike_clusters = appdoc_struct;
                fields_needed = {'epoch_info', 'clusterinfo'};
                sizes_needed = {[1 -1], [1 -1]};
                % check parameters here
                [b,errormsg] = vlt.data.hasAllFields(spike_clusters, fields_needed, sizes_needed);
            else
                error(['Unknown appdoc_type' appdoc_type '.']);
            end
        end % isvalid_appdoc_struct()

        function doc = find_appdoc(ndi_app_spikesorter_obj, appdoc_type, varargin)
            % FIND_APPDOC - find an ndi_app_appdoc document in the session database
            %
            % See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
            %
            doc = {};

            switch(lower(appdoc_type))
                case 'sorting_parameters'
                    sorting_parameters_name = varargin{1};

                    sorting_search = ndi.query('base.name','exact_string',sorting_parameters_name,'') & ...
                        ndi.query('','isa','sorting_parameters', '');
                    doc = ndi_app_spikesorter_obj.session.database_search(sorting_search);

                case 'spike_clusters'
                    ndi_timeseries_obj = varargin{1};
                    extraction_name = varargin{2};
                    sorting_parameters_name = varargin{3};
                    spike_clusters_name = varargin{1};

                    % get the extraction parameters doc
                    se = ndi.app.spikeextractor(ndi_app_spikesorter_obj.session);
                    extraction_parameters_doc = se.find_appdoc('extraction_parameters',extraction_name);
                    if numel(extraction_parameters_doc)==0,
                        % disp('no extraction doc, returning');
                        return;
                    elseif numel(extraction_parameters_doc)>1,
                        error(['Too many extraction parameters docs. Should not happen.']);
                    else,
                        extraction_parameters_doc = extraction_parameters_doc{1};
                    end;

                    % get the sorting parameters doc
                    sorting_parameters_doc = ndi_app_spikesorter_obj.find_appdoc('sorting_parameters', sorting_parameters_name);
                    if numel(sorting_parameters_doc)==0,
                        % disp('no sorting parameters doc, returning');
                        return;
                    elseif numel(sorting_parameters_doc)>1,
                        error(['Too many sorting parameters doc. Should not happen.']);
                    else,
                        sorting_parameters_doc = sorting_parameters_doc{1};
                    end;

                    cluster_search = ndi.query('','isa','spike_clusters','') & ...
                        ndi.query('','depends_on','element_id',ndi_timeseries_obj.id()) & ...
                        ndi.query('','depends_on','sorting_parameters_id', sorting_parameters_doc.id()) & ...
                        ndi.query('','depends_on','extraction_parameters_id',extraction_parameters_doc.id());

                    doc = ndi_app_spikesorter_obj.session.database_search(cluster_search);

                otherwise
                    error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
            end %switch
        end % find_appdoc()

        function varargout = loaddata_appdoc(ndi_app_spikesorter_obj, appdoc_type, varargin)
            % LOADDATA_APPDOC - load data from an application document
            %
            % See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
            %
            switch(lower(appdoc_type))
                case 'sorting_parameters',
                    varargout{1} = ndi_app_spikesorter_obj.find_appdoc(appdoc_type,varargin{:});
                case 'spike_clusters',
                    spike_clusters_doc = ndi_app_spikesorter_obj.find_appdoc(appdoc_type,varargin{:});
                    if numel(spike_clusters_doc)==0,
                        varargout{1} = [];
                        varargout{2} = [];
                        return;
                    elseif numel(spike_clusters_doc)>1,
                        error(['Too many spike clusters docs found!']);
                    else,
                        spike_clusters_doc = spike_clusters_doc{1};
                    end;
                    spike_clusters_binarydoc = ndi_app_spikesorter_obj.session.database_openbinarydoc(spike_clusters_doc,'spike_cluster.bin');
                    varargout{1} = spike_clusters_binarydoc.fread(inf,'uint16');
                    varargout{2} = spike_clusters_doc;
                    ndi_app_spikesorter_obj.session.database_closebinarydoc(spike_clusters_binarydoc);
                otherwise
                    error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
            end %switch
        end % loaddata_appdoc()

        function appdoc_description(ndi_app_appdoc_obj)
            % APPDOC_DESCRIPTION - a function that prints a description of all appdoc types
            %
            % For ndi_app_spikeextractor, there are the following types:
            % APPDOC_TYPE                 | Description
            % ----------------------------------------------------------------------------------------------
            % 'sorting_parameters'        | A document that describes the parameters to be used for sorting
            % 'spike_clusters'            | A document that contains the assignment of a set of spikes to clusters
            % ----------------------------------------------------------------------------------------------
            %
            % ----------------------------------------------------------------------------------------------
            % APPDOC 1: SORTING_PARAMETERS
            % ----------------------------------------------------------------------------------------------
            %
            %   ----------------------------------
            %   | SORTING_PARAMETERS -- ABOUT |
            %   ----------------------------------
            %
            %   SORTING_PARAMETERS documents hold the parameters that are to be used to guide the extraction of
            %   spikewaves.
            %
            %   Definition: apps/spikesorter/sorting_parameters.json
            %
            %   -------------------------------------
            %   | SORTING_PARAMETERS -- CREATION |
            %   -------------------------------------
            %
            %   DOC = STRUCT2DOC(NDI_APP_SPIKESORTER_OBJ, 'sorting_parameters', SORTING_PARAMS, SORTING_PARAMETERS_NAME)
            %
            %   SORTING_NAME is a string containing the name of the extraction document.
            %
            %   SORTING_PARAMS should contain the following fields:
            %   Fieldname                 | Description
            %   -------------------------------------------------------------------------
            %   graphical_mode (1)        | Should we use graphical mode (1) or automatic mode (0)?
            %   num_pca_features (10)     | Number of pca-driven features to use in the clustering calculation in automatic mode
            %   interpolation (3)         | By how many times should we oversample the spikes, interpolating by splines?
            %   min_clusters (3)          | Minimum clusters parameter for KlustaKwik in automatic mode
            %   max_clusters (10)         | Maximum clusters parameter for KlustaKwik in automatic mode
            %   num_start (5)             | Number of random starting positions in automatic mode
            %
            %
            %   ------------------------------------
            %   | SORTING_PARAMETERS -- FINDING |
            %   ------------------------------------
            %
            %   [SORTING_PARAMETERS_DOC] = FIND_APPDOC(NDI_APP_SPIKESORTER_OBJ, ...
            %        'sorting_parameters', SORTING_PARAMETERS_NAME)
            %
            %   INPUTS:
            %     SORTING_PARAMETERS_NAME - the name of the sorting parameter document
            %   OUTPUT:
            %     Returns the sorting parameters ndi.document with the name SORTING_PARAMETERS_NAME.
            %
            %   ------------------------------------
            %   | SORTING_PARAMETERS -- LOADING |
            %   ------------------------------------
            %
            %   [SORTING_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKESORTER_OBJ, ...
            %        'sorting_parameters', SORTING_PARAMETERS_NAME)
            %
            %   INPUTS:
            %     SORTING_PARAMETERS_NAME - the name of the sorting parameter document
            %   OUTPUT:
            %     Returns the sorting parameters ndi.document with the name SORTING_PARAMETERS_NAME.
            %
            % ----------------------------------------------------------------------------------------------
            % APPDOC 2: SPIKE_CLUSTERS
            % ----------------------------------------------------------------------------------------------
            %
            %   ---------------------------
            %   | SPIKE_CLUSTERS -- ABOUT |
            %   ---------------------------
            %
            %   SPIKEWAVES documents store the spike waveforms that are read during a spike extraction. It
            %   DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the SORTING_PARAMETERS
            %   that described the extraction.
            %
            %   Definition: apps/spikesorter/spike_clusters
            %
            %   ------------------------------
            %   | SPIKE_CLUSTERS -- CREATION |
            %   ------------------------------
            %
            %   Spike cluster documents are created internally by the SORT function
            %
            %   ----------------------------
            %   | SPIKE_CLUSTERS - FINDING |
            %   ----------------------------
            %
            %   [SPIKE_CLUSTERS_DOC] = FIND_APPDOC(NDI_APP_SPIKESORTER_OBJ, 'spike_clusters', ...
            %                               NDI_TIMESERIES_OBJ, SORTING_PARAMETERS_NAME)
            %
            %   INPUTS:
            %      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
            %      SORTING_PARAMETERS_NAME - the name of the sorting parameters document used in the sorting
            %   OUTPUT:
            %      SPIKECLUSTERS_DOC - the ndi.document of the cluster information
            %
            %   ----------------------------
            %   | SPIKE_CLUSTERS - LOADING |
            %   ----------------------------
            %
            %   [CLUSTERIDS, SPIKE_CLUSTERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKESORTER_OBJ, 'spike_clusters', ...
            %                               NDI_TIMESERIES_OBJ, SORTING_PARAMETERS_NAME, EXTRACTION_PARAMETERS_NAME)
            %
            %   INPUTS:
            %      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
            %      SORTING_PARAMETERS_NAME - the name of the sorting parameters document used in the sorting
            %      EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
            %
            %   OUTPUTS:
            %      CLUSTERIDS: the cluster id number of each spike
            %      SPIKE_CLUSTERS_DOC - the ndi.document of the clusters, which includes detailed cluster information.
            %
            eval(['help ndi_app_spikesorter/appdoc_description']);
        end; % appdoc_description()

    end % methods

end % ndi.app.spikesorter
