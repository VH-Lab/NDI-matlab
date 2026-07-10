function [ensemble_doc, existing] = create(S, element, epochid, options)
% ndi.fun.ensemble.create - build and store an 'ensemble' ndi.document for an epoch
%
% [ENSEMBLE_DOC, EXISTING] = ndi.fun.ensemble.CREATE(S, ELEMENT, EPOCHID, ...)
%
% Builds an 'ensemble' ndi.document for the spiking neurons recorded during
% epoch EPOCHID of ELEMENT. The ensemble activity is looked up by this function
% (with ndi.fun.ensemble.load), which reads the spike times of every neuron
% recorded in that epoch; the neuron ids and names are discovered the same way.
% The activity is stored as an attached '.ndisparse' binary file and the neuron
% names in an attached text file. The document depends on ELEMENT (dependency
% 'element_id') and on each neuron element ('neuron_id_1', 'neuron_id_2', ...).
%
% Before storing, CREATE checks whether an ensemble with the same element,
% neurons, names, and epoch already exists and, if so, raises an error (unless
% the 'CheckExisting' option is false). This prevents accidental duplicates.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S        - an ndi.session or ndi.dataset object.
%   ELEMENT  - the element (usually a probe) that the ensemble belongs to and
%              that provides the time reference. An ndi.element object or an
%              element document id string.
%   EPOCHID  - the epoch id (of ELEMENT) to build the ensemble for.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   neurons ({})                 - restrict the ensemble to these neuron
%                                  elements (objects or ids); default is every
%                                  'spikes' element built on ELEMENT (having
%                                  ELEMENT as its underlying element) that is
%                                  recorded in EPOCHID.
%   clocktype ('')               - clock to express spike times in; default is
%                                  ELEMENT's clock for EPOCHID.
%   ensemble_name ('')           - a human-readable label for the ensemble.
%   value_type ('spiketimes')    - short code for what the stored values mean.
%   value_description ('')       - free text describing the values.
%   CheckExisting (true)         - if true, error when a matching ensemble
%                                  document already exists.
%   add_to_database (false)      - if true, add the document to S's database.
%   Verbose (false)              - print progress messages.
%
% =========================================================================
% OUTPUTS
% =========================================================================
%   ENSEMBLE_DOC - the created ndi.document (with the binary and text files
%                  registered). If add_to_database is false, the files are in
%                  temporary locations and are copied into the database when
%                  the document is added with S.database_add.
%   EXISTING     - a cell array of any pre-existing matching ensemble documents
%                  that were found (empty if none). When CheckExisting is true
%                  and this is non-empty, an error is raised instead of
%                  returning.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   doc = ndi.fun.ensemble.create(S, probe, 'epoch_1', ...
%       'ensemble_name', 'V1 ensemble', 'add_to_database', true);
%
% See also: ndi.fun.ensemble.load, ndi.fun.ensemble.read,
%   ndi.fun.ensemble.findExisting

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
        options.add_to_database (1,1) logical = false
        options.Verbose (1,1) logical = false
    end

    vb = options.Verbose;

    element_id = local_id(element);
    local_v(vb, ['building ensemble for element ' element_id ', epoch ' epochid '...']);

    % --- look up the ensemble activity, neurons, and names -----------------
    [activity, neuron_ids, neuron_names, info] = ndi.fun.ensemble.load(S, element, epochid, ...
        'neurons', options.neurons, 'clocktype', options.clocktype, ...
        'value_type', options.value_type, ...
        'value_description', options.value_description, ...
        'Verbose', options.Verbose);

    if isempty(neuron_ids)
        warning('ndi:ensemble:create:noNeurons', ...
            ['No neurons were found recorded in epoch ''%s'' of the element; ' ...
            'the ensemble will be empty.'], epochid);
    end

    % --- refuse to create a duplicate --------------------------------------
    existing = {};
    if options.CheckExisting
        local_v(vb, ['checking for an existing ensemble with the same element, ' ...
            int2str(numel(neuron_ids)) ' neuron(s), and epoch ' epochid '...']);
        existing = ndi.fun.ensemble.findExisting(S, element_id, neuron_ids, ...
            neuron_names, 'epochid', epochid);
        if ~isempty(existing)
            local_v(vb, ['found a matching ensemble (document id ' existing{1}.id() '); raising an error.']);
            error('ndi:ensemble:create:exists', ...
                ['An ensemble document with the same element, neurons, and ' ...
                'epoch already exists (document id %s). Pass ' ...
                '''CheckExisting'', false to create it anyway.'], existing{1}.id());
        end
        local_v(vb, 'no matching ensemble found; proceeding.');
    else
        local_v(vb, 'skipping the existing-ensemble check (CheckExisting is false).');
    end

    % --- write the activity to a temporary sparse file ---------------------
    local_v(vb, ['writing activity (' int2str(info.num_neurons) ' neuron(s) x ' ...
        int2str(size(activity,2)) ' column(s), ' int2str(nnz(activity)) ' nonzero(s)).']);
    activity_tempfile = [ndi.file.temp_name() '.ndisparse'];
    ndi.util.writeSparse(activity_tempfile, activity);

    % --- write the neuron names to a temporary text file -------------------
    local_v(vb, ['writing ' int2str(numel(neuron_names)) ' neuron name(s) to a text file.']);
    names_tempfile = [ndi.file.temp_name() '.txt'];
    fid = fopen(names_tempfile, 'w');
    if fid<0
        error('ndi:ensemble:create:cannotOpen', ...
            'Could not open a temporary file for the neuron names.');
    end
    for i=1:numel(neuron_names)
        fprintf(fid, '%s\n', neuron_names{i});
    end
    fclose(fid);

    % --- application provenance --------------------------------------------
    app_version = '';
    try
        app_version = ndi.version();
    catch
    end

    % --- build the document ------------------------------------------------
    local_v(vb, 'building the ensemble document and its dependencies.');
    ensemble_doc = S.newdocument('ensemble', ...
        'ensemble.ensemble_name', options.ensemble_name, ...
        'ensemble.value_type', info.value_type, ...
        'ensemble.value_description', info.value_description, ...
        'ensemble.num_neurons', info.num_neurons, ...
        'ensemble.num_dimensions', info.num_dimensions, ...
        'ensemble.clocktype', info.clocktype, ...
        'epochid.epochid', epochid, ...
        'app.name', 'ndi.fun.ensemble', ...
        'app.version', app_version);

    % dependency on the owning element (the probe)
    ensemble_doc = ensemble_doc.set_dependency_value('element_id', element_id);

    % one numbered dependency per neuron element
    for i=1:numel(neuron_ids)
        ensemble_doc = ensemble_doc.add_dependency_value_n('neuron_id', neuron_ids{i});
    end

    % attach the binary and text files
    ensemble_doc = ensemble_doc.add_file('ensemble_activity.ndisparse', activity_tempfile);
    ensemble_doc = ensemble_doc.add_file('neuron_names.txt', names_tempfile);

    if options.add_to_database
        local_v(vb, ['adding the ensemble document (id ' ensemble_doc.id() ') to the database.']);
        S.database_add(ensemble_doc);
    else
        local_v(vb, ['created ensemble document (id ' ensemble_doc.id() '); not added to ' ...
            'the database (add_to_database is false).']);
    end

end % create()

% -------------------------------------------------------------------------

function local_v(verbose, msg)
% print a create() progress message when verbose
    if verbose
        disp(['ndi.fun.ensemble.create: ' msg]);
    end
end % local_v()

% -------------------------------------------------------------------------

function id = local_id(x)
% return a document id string from an object (via id()) or a char id
    if ischar(x) || (isstring(x) && isscalar(x))
        id = char(x);
    elseif isobject(x) && ismethod(x,'id')
        id = x.id();
    else
        error('ndi:ensemble:create:badId', ...
            ['Could not determine a document id; provide a char id or an ' ...
            'object with an id() method.']);
    end
end % local_id()
