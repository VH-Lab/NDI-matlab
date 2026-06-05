function [info, summary] = extracellularInfo(S, probe, options)
% NDI.FUN.PROBE.EXTRACELLULARINFO - summarize the extracellular neurons imported from a probe
%
% [INFO, SUMMARY] = NDI.FUN.PROBE.EXTRACELLULARINFO(S, PROBE, ...)
%
% Returns information about the extracellular neurons that were determined
% (e.g. spike-sorted and imported) from the ndi.probe (or ndi.element) PROBE in
% the ndi.session S. This is a way of viewing data that has ALREADY been
% imported into the database; nothing is read from disk and nothing is changed.
% It is the database-side counterpart to NDI.FUN.PROBE.IMPORT.KILOSORT.GETINFO,
% which summarizes a sort on disk before it is imported.
%
% A neuron is considered to belong to PROBE if it is an ndi.element whose
% underlying element is PROBE (depends_on 'underlying_element_id' == PROBE.id())
% and that has an associated 'neuron_extracellular' document (depends_on
% 'element_id' == that neuron element). This is exactly the relationship created
% by NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE.
%
% INFO is a struct array (one entry per neuron, sorted by cluster_index) with
% fields:
%   element_name         - name of the neuron ndi.element (e.g. 'probe_3')
%   element_id           - document id of the neuron element
%   cluster_index        - cluster id the neuron came from (from the document)
%   quality_label        - curation label (e.g. 'good', 'mua')
%   quality_number       - numeric quality value
%   number_of_channels   - number of channels in the mean waveform
%   number_of_samples_per_channel - samples per channel in the mean waveform
%   neuron_extracellular - the full 'neuron_extracellular' property structure
%                            from the document (mean_waveform, etc.)
%   document             - the neuron_extracellular ndi.document object
%
% If PROBE has no imported extracellular neurons, INFO is a 0x0 struct array
% with these fields and SUMMARY says so.
%
% SUMMARY is a multiline character array giving a human-readable version of INFO.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | quality_labels ([])      | If non-empty, a string array restricting the result |
% |                          |   to neurons whose quality_label is in the list      |
% |                          |   (matched case-insensitively).                     |
% ---------------------------------------------------------------------------------
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    [info, summary] = ndi.fun.probe.extracellularInfo(S, p{1});
%    disp(summary);
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.IMPORT.KILOSORT.GETINFO

    arguments
        S
        probe
        options.quality_labels (1,:) string = string.empty
    end

    % Step 1: find the neuron ndi.elements whose underlying element is this probe.
    % Only element documents carry an 'underlying_element_id' dependency, so this
    % returns the elements (neurons and any other elements) built on the probe.
    q_elem = ndi.query('','isa','element','') & ...
        ndi.query('','depends_on','underlying_element_id', probe.id());
    elem_docs = S.database_search(q_elem);

    % Map neuron element id -> element name for quick lookup.
    elem_name_map = containers.Map('KeyType','char','ValueType','char');
    for i=1:numel(elem_docs),
        elem_name_map(elem_docs{i}.id()) = elem_docs{i}.document_properties.element.name;
    end;

    % Step 2: find every neuron_extracellular document and keep those whose
    % element_id is one of the probe's neuron elements.
    q_ne = ndi.query('','isa','neuron_extracellular','');
    ne_docs = S.database_search(q_ne);

    % Step 3: assemble the result entries.
    entries = struct('element_name',{},'element_id',{},'cluster_index',{}, ...
        'quality_label',{},'quality_number',{}, ...
        'number_of_channels',{},'number_of_samples_per_channel',{}, ...
        'neuron_extracellular',{},'document',{});

    want = lower(string(options.quality_labels));

    for i=1:numel(ne_docs),
        element_id = ne_docs{i}.dependency_value('element_id');
        if isempty(element_id) || ~isKey(elem_name_map, element_id),
            continue; % this neuron does not belong to PROBE
        end;
        ne = ne_docs{i}.document_properties.neuron_extracellular;
        if ~isempty(want) && ~any(want==lower(string(ne.quality_label))),
            continue; % filtered out by quality_labels
        end;
        e = struct();
        e.element_name = elem_name_map(element_id);
        e.element_id = element_id;
        e.cluster_index = ne.cluster_index;
        e.quality_label = ne.quality_label;
        e.quality_number = ne.quality_number;
        e.number_of_channels = ne.number_of_channels;
        e.number_of_samples_per_channel = ne.number_of_samples_per_channel;
        e.neuron_extracellular = ne;
        e.document = ne_docs{i};
        entries(end+1) = e; %#ok<AGROW>
    end;

    % Step 4: sort by cluster_index for a stable, intuitive ordering.
    if ~isempty(entries),
        [~,order] = sort([entries.cluster_index]);
        entries = entries(order);
    end;
    info = entries;

    % Step 5: build the multiline character summary.
    nl = newline;
    lines = {};
    lines{end+1} = ['Imported extracellular neurons for probe ''' probe.elementstring() ''''];
    lines{end+1} = ['  Neurons:          ' int2str(numel(info))];
    if isempty(info),
        lines{end+1} = '  (no neuron_extracellular documents depend on this probe)';
    else,
        % tag breakdown
        labels = string({info.quality_label});
        [utags,~,ic] = unique(labels);
        counts = accumarray(ic(:),1);
        lines{end+1} = '  Quality labels:';
        for i=1:numel(utags),
            lines{end+1} = ['     ' char(utags(i)) ': ' int2str(counts(i)) ' neuron(s)'];
        end;
        lines{end+1} = '  Neurons (name, cluster, quality, waveform):';
        for i=1:numel(info),
            lines{end+1} = ['     ' info(i).element_name ...
                ' (cluster ' int2str(info(i).cluster_index) ', ' ...
                info(i).quality_label ', quality ' num2str(info(i).quality_number) ', ' ...
                int2str(info(i).number_of_channels) ' ch x ' ...
                int2str(info(i).number_of_samples_per_channel) ' samp)'];
        end;
    end;

    summary = strjoin(lines, nl);

end
