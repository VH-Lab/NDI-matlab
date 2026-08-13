function [ensembleElement, existing] = create(S, element, epochid, options)
% ndi.fun.ensemble.create - build an ensemble element's epoch and store it
%
% [ENSEMBLEELEMENT, EXISTING] = ndi.fun.ensemble.CREATE(S, ELEMENT, EPOCHID, ...)
%
% Builds (or extends) the ndi.element.ensemble for ELEMENT (usually a probe) by
% adding the epoch EPOCHID. The ensemble activity is looked up by this function
% (with ndi.fun.ensemble.load): it reads the spike times of every neuron
% recorded on ELEMENT during EPOCHID, and stores them in the ensemble element as
% a marked point process (a standard element_epoch/vhsb binary) plus a per-epoch
% 'ensemble' map document recording the neuron ids and names for that epoch's
% columns.
%
% The ensemble element is found-or-created for ELEMENT (one ensemble element per
% probe, named [ELEMENT.name '_ensemble']); constructing it adds its element
% document to the database. This call then adds the EPOCHID data.
%
% Before adding, CREATE checks whether the ensemble element already has an
% ensemble for EPOCHID and, if so, raises an error, unless CheckExisting is
% false.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S        - an ndi.session or ndi.dataset object.
%   ELEMENT  - the element (usually a probe) whose neurons form the ensemble and
%              that provides the time reference. An ndi.element/ndi.probe object
%              or an element document id string.
%   EPOCHID  - the epoch id (of ELEMENT) to build the ensemble for.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   neurons ({})                 - restrict to these neuron elements; default is
%                                  every 'spikes' element built on ELEMENT that
%                                  is recorded in EPOCHID.
%   clocktype ('')               - clock to express spike times in; default is
%                                  ELEMENT's clock for EPOCHID.
%   ensemble_name ('')           - a human-readable label stored in the map doc.
%   value_type ('spiketimes')    - short code for what the stored values mean.
%   value_description ('')       - free text describing the values.
%   CheckExisting (true)         - if true, error when the ensemble element
%                                  already has an ensemble for EPOCHID.
%   SkipIfEmpty (false)          - if true and no neurons are recorded in
%                                  EPOCHID, add nothing and return the ensemble
%                                  element as-is.
%   add_to_database (true)       - if true, add the epoch and map documents to
%                                  the database.
%   Verbose (false)              - print progress messages.
%
% =========================================================================
% OUTPUT
% =========================================================================
%   ENSEMBLEELEMENT - the ndi.element.ensemble (with the EPOCHID epoch added).
%   EXISTING        - a cell array of any pre-existing 'ensemble' map documents
%                     found for this ensemble element and epoch (empty if none).
%                     When CheckExisting is true and this is non-empty, an error
%                     is raised instead of returning.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   ens = ndi.fun.ensemble.create(S, probe, 'epoch_1', 'ensemble_name', 'V1');
%   [neuronIndex, spikeTime] = ens.readtimeseries('epoch_1', -Inf, Inf);
%
% See also: ndi.element.ensemble, ndi.fun.ensemble.load,
%   ndi.fun.ensemble.read, ndi.fun.ensemble.findExisting

    arguments
        S
        element
        epochid (1,:) char
        options.neurons cell = {}
        options.clocktype (1,:) char = ''
        options.ensemble_name (1,:) char = ''
        options.value_type (1,:) char = 'spiketimes'
        options.value_description (1,:) char = ''
        options.CheckExisting (1,1) logical = true
        options.SkipIfEmpty (1,1) logical = false
        options.add_to_database (1,1) logical = true
        options.Verbose (1,1) logical = false
    end

    vb = options.Verbose;
    existing = {};

    probe = local_object(element, S);
    local_v(vb, ['building ensemble for element ' probe.id() ', epoch ' epochid '...']);

    % --- look up this epoch's neurons, names, and spike trains -------------
    [~, neuron_ids, neuron_names, info, spike_rows] = ndi.fun.ensemble.load(S, probe, epochid, ...
        'neurons', options.neurons, 'clocktype', options.clocktype, ...
        'value_type', options.value_type, ...
        'value_description', options.value_description, ...
        'Verbose', vb);

    % --- find or create the ensemble element for this probe ---------------
    ensembleElement = ensembleElementFor(S, probe);

    if isempty(neuron_ids)
        if options.SkipIfEmpty
            local_v(vb, ['no neurons recorded in epoch ' epochid '; skipping ' ...
                '(SkipIfEmpty is true).']);
            return;
        end
        warning('ndi:ensemble:create:noNeurons', ...
            ['No neurons were found recorded in epoch ''%s'' of the element; ' ...
            'the ensemble epoch will be empty.'], epochid);
    end

    % --- refuse to duplicate an epoch -------------------------------------
    if options.CheckExisting
        local_v(vb, ['checking for an existing ensemble for epoch ' epochid '...']);
        existing = ndi.fun.ensemble.findExisting(S, ensembleElement, 'epochid', epochid);
        if ~isempty(existing)
            local_v(vb, ['found an existing ensemble (document id ' existing{1}.id() '); raising an error.']);
            error('ndi:ensemble:create:exists', ...
                ['The ensemble element already has an ensemble for epoch %s ' ...
                '(map document id %s). Pass ''CheckExisting'', false to add it ' ...
                'anyway.'], epochid, existing{1}.id());
        end
        local_v(vb, 'no existing ensemble found; proceeding.');
    end

    % --- add the epoch to the ensemble element ----------------------------
    local_v(vb, ['adding epoch ' epochid ' (' int2str(numel(neuron_ids)) ...
        ' neuron(s)) to the ensemble element.']);
    ensembleElement = ensembleElement.addEnsembleEpoch(epochid, info.clock, info.t0_t1, ...
        neuron_ids, neuron_names, spike_rows, ...
        'value_type', info.value_type, ...
        'value_description', info.value_description, ...
        'ensemble_name', options.ensemble_name, ...
        'add_to_database', options.add_to_database);

end % create()

% -------------------------------------------------------------------------

function obj = local_object(x, S)
% return an ndi.element/ndi.probe object from an object or a document id string
    if isa(x, 'ndi.element')
        obj = x;
    elseif ischar(x) || (isstring(x) && isscalar(x))
        obj = ndi.database.fun.ndi_document2ndi_object(char(x), S);
        if isempty(obj)
            error('ndi:ensemble:create:badElement', ...
                'Could not load an ndi.element for document id ''%s''.', char(x));
        end
    else
        error('ndi:ensemble:create:badElement', ...
            'ELEMENT must be an ndi.element/ndi.probe object or a document id string.');
    end
end % local_object()

function local_v(verbose, msg)
    if verbose
        disp(['ndi.fun.ensemble.create: ' msg]);
    end
end % local_v()
