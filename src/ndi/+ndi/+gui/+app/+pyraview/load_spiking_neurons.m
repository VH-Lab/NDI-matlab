function spiking_info = load_spiking_neurons(session, probe, epochid)
% LOAD_SPIKING_NEURONS - Load spiking neuron information for a probe
%
%   SPIKING_INFO = ndi.gui.app.pyraview.load_spiking_neurons(SESSION, PROBE, EPOCHID)
%
%   Inputs:
%       SESSION - An ndi.session object
%       PROBE   - An ndi.probe object
%       EPOCHID - String identifier for the epoch
%
%   Outputs:
%       SPIKING_INFO - Struct array with fields:
%                      'element_obj' : The NDI element object (empty until
%                                      constructed lazily on first selection)
%                      'element_doc' : The NDI element document
%                      'neuron_doc'  : The associated neuron_extracellular document
%                      'label'       : Display label
%                      'name'        : Element name string (for sorting)
%                      'quality'     : Neuron quality number
%                      'spike_times' : Vector of spike times (loaded lazily; see
%                                      'times_loaded')
%                      'times_loaded': Logical; false until spike_times have been
%                                      read on demand for a selected unit
%                      'best_channel': Scalar channel index of max energy
%                      'low_channel' : Lowest channel index whose mean-waveform
%                                      peak-to-peak amplitude is >= 10% of the
%                                      maximum across channels
%                      'high_channel': Highest such channel index
%
%   Note: for populations with hundreds of units, two operations dominate
%   load time -- reconstructing each element object (ndi_document2ndi_object)
%   and reading each unit's spike train (readtimeseries). Neither is done
%   here. 'element_obj' is left empty and 'spike_times' is left empty with
%   'times_loaded' false; callers build the object and read the spike times
%   on demand the first time a unit is selected for display.
%

    arguments
        session (1,1) ndi.session
        probe (1,1) {mustBeA(probe, 'ndi.probe')}
        epochid (1,:) char
    end

    spiking_info = struct('element_obj', {}, 'element_doc', {}, 'neuron_doc', {}, ...
                          'label', {}, 'name', {}, 'quality', {}, ...
                          'spike_times', {}, 'times_loaded', {}, 'best_channel', {}, ...
                          'low_channel', {}, 'high_channel', {});

    % 1. Find all spike elements for this probe
    Q1 = ndi.query('element.type', 'exact_string', 'spikes');
    Q2 = ndi.query('', 'depends_on', 'underlying_element_id', probe.id());
    element_docs = session.database_search(Q1 & Q2);

    if isempty(element_docs)
        return;
    end

    % 2. Find all neuron_extracellular documents in the session
    Q_neuron = ndi.query('', 'isa', 'neuron_extracellular');
    all_neuron_docs = session.database_search(Q_neuron);

    % Build an element_id -> neuron_doc map in a single pass so that matching
    % each element below is an O(1) lookup instead of an O(N^2) rescan.
    neuron_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for j = 1:numel(all_neuron_docs)
        try
            dep_id = all_neuron_docs{j}.dependency_value('element_id');
            neuron_map(dep_id) = all_neuron_docs{j};
        catch
        end
    end

    % Initialize Progress Bar
    pb_fig = figure('Name', 'Loading Spiking Neurons', 'NumberTitle', 'off', 'MenuBar', 'none', ...
                    'ToolBar', 'none', 'Resize', 'off', 'Position', [500 500 520 80]);
    pb = ndi.gui.component.NDIProgressBar('Parent', pb_fig, ...
        'Message', 'Loading...', 'Text', 'Initializing...');

    cleanupObj = onCleanup(@() delete(pb_fig));

    % 3. Match elements to neurons
    num_elements = numel(element_docs);
    for i = 1:num_elements
        % Update Progress
        progress = i / num_elements;
        pb.Value = progress;
        pb.Message = sprintf('Loading unit %d of %d...', i, num_elements);
        drawnow;

        el_doc = element_docs{i};
        el_id = el_doc.id();

        % Find matching neuron doc (O(1) lookup)
        n_doc = [];
        if neuron_map.isKey(el_id)
            n_doc = neuron_map(el_id);
        end

        quality = 0;
        best_ch = 1; % Default
        low_ch = 1;  % Lowest channel with a significant waveform peak
        high_ch = 1; % Highest channel with a significant waveform peak

        if ~isempty(n_doc)
            % Extract Quality
            if isfield(n_doc.document_properties, 'neuron_extracellular')
               if isfield(n_doc.document_properties.neuron_extracellular, 'quality_number')
                   quality = n_doc.document_properties.neuron_extracellular.quality_number;
               elseif isfield(n_doc.document_properties.neuron_extracellular, 'quality')
                   quality = n_doc.document_properties.neuron_extracellular.quality;
               end

               % Calculate Best Channel (Max Energy) and the span of channels
               % carrying a significant part of the waveform.
               if isfield(n_doc.document_properties.neuron_extracellular, 'mean_waveform')
                   w = n_doc.document_properties.neuron_extracellular.mean_waveform;
                   % w is Samples x Channels
                   % Energy E = sum(w.^2, 1) -> 1 x Channels
                   E = sum(w.^2, 1);
                   if ~isempty(E)
                       [~, best_ch] = max(E);
                   end

                   % Per-channel peak-to-peak amplitude. The box drawn for
                   % each spike spans from the lowest to the highest channel
                   % whose peak is at least 10% of the maximum channel peak.
                   ch_amp = max(w, [], 1) - min(w, [], 1); % 1 x Channels
                   max_amp = max(ch_amp);
                   if ~isempty(max_amp) && max_amp > 0
                       signif = find(ch_amp >= 0.10 * max_amp);
                       if ~isempty(signif)
                           low_ch = min(signif);
                           high_ch = max(signif);
                       end
                   end
               end
            end
        end

        % Neither the element object nor the spike times are built here -- see
        % the note in the help above. Reconstructing every element object
        % (ndi_document2ndi_object) and reading every unit's train up front were
        % the two bottlenecks when loading hundreds of neurons. Both are done
        % lazily, the first time a unit is selected.
        %
        % The display name is derived directly from the element document so it
        % matches ndi.element/elementstring ([name ' | ' int2str(reference)])
        % without constructing the object.
        name = '';
        try
            el_props = el_doc.document_properties.element;
            if isfield(el_props, 'reference')
                name = [el_props.name ' | ' int2str(el_props.reference)];
            else
                name = el_props.name;
            end
        catch
            name = el_id;
        end
        label = sprintf('%d %s Q%d', i, name, quality);

        spiking_info(i).element_obj = []; % constructed lazily on first selection
        spiking_info(i).element_doc = el_doc;
        spiking_info(i).neuron_doc = n_doc;
        spiking_info(i).label = label;
        spiking_info(i).name = name;
        spiking_info(i).quality = quality;
        spiking_info(i).spike_times = [];
        spiking_info(i).times_loaded = false;
        spiking_info(i).best_channel = best_ch;
        spiking_info(i).low_channel = low_ch;
        spiking_info(i).high_channel = high_ch;
    end
end
