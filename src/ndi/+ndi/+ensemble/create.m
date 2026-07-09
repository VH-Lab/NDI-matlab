function ensemble_doc = create(S, element, neuron_ids, neuron_names, activity, options)
% ndi.ensemble.create - build an 'ensemble' ndi.document from ensemble activity
%
% ENSEMBLE_DOC = ndi.ensemble.CREATE(S, ELEMENT, NEURON_IDS, NEURON_NAMES, ACTIVITY, ...)
%
% Creates an 'ensemble' ndi.document that stores the activity of a group of
% neurons (an "ensemble") recorded from a common element (usually a probe),
% for one epoch. The activity is stored as a sparse array in a binary file
% attached to the document, and the neuron element names are stored in a text
% file attached to the document. The document depends on the owning ELEMENT
% (dependency 'element_id') and on each neuron element (dependencies
% 'neuron_id_1', 'neuron_id_2', ...).
%
% =========================================================================
% INPUTS
% =========================================================================
%   S            - an ndi.session or ndi.dataset object.
%   ELEMENT      - the element (usually an ndi.probe) that the ensemble
%                  belongs to. May be an ndi.element/ndi.probe object (its
%                  .id() is used) or a document id string.
%   NEURON_IDS   - a cell array of the ndi.element document id strings of the
%                  neurons that make up the ensemble. Each may also be an
%                  object with an id() method. Row i of ACTIVITY corresponds
%                  to NEURON_IDS{i}.
%   NEURON_NAMES - a cell array of char, one human-readable name per neuron
%                  (e.g. the element string). Must have the same number of
%                  entries as NEURON_IDS. Written, one per line, to the
%                  document's neuron_names.txt file.
%   ACTIVITY     - the ensemble activity, in one of two forms:
%                    * a 2-D MATLAB matrix (sparse or full), e.g. an
%                      N-neurons-by-Smax matrix of spike times; or
%                    * a struct with fields 'subs' (nnz-by-ndims, 1-based),
%                      'vals' (nnz-by-1), and 'size' (1-by-ndims) describing a
%                      sparse N-dimensional array.
%                  It is written with ndi.util.writeSparse.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   epochid ('')            - the epoch id this ensemble corresponds to.
%   ensemble_name ('')      - a human-readable label for the ensemble.
%   value_type ('')         - short code for what the stored values mean,
%                             e.g. 'spiketimes', 'firingrate', 'binary'.
%   value_description ('')  - free text describing the meaning/units of the
%                             stored values.
%   clocktype ('')          - name of the ndi.time.clocktype the values are
%                             expressed in, if the values are times.
%   add_to_database (false) - if true, the document is added to S's database
%                             (via S.database_add) before returning.
%
% =========================================================================
% OUTPUT
% =========================================================================
%   ENSEMBLE_DOC - the created ndi.document. If add_to_database is false, the
%                  binary and text files have been written to temporary files
%                  and registered with the document; they are copied into the
%                  database (and the temporaries removed) when the document is
%                  added with S.database_add.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   % E is a sparse N-by-Smax matrix; neuron_ids and neuron_names are 1xN
%   doc = ndi.ensemble.create(S, probe, neuron_ids, neuron_names, E, ...
%       'epochid', epochid, 'value_type', 'spiketimes', ...
%       'value_description', 'time of n-th spike of neuron i', ...
%       'clocktype', 'dev_local_time', 'add_to_database', true);
%
% See also: ndi.ensemble.read, ndi.util.writeSparse, ndi.util.readSparse

    arguments
        S
        element
        neuron_ids cell
        neuron_names cell
        activity
        options.epochid (1,:) char = ''
        options.ensemble_name (1,:) char = ''
        options.value_type (1,:) char = ''
        options.value_description (1,:) char = ''
        options.clocktype (1,:) char = ''
        options.add_to_database (1,1) logical = false
    end

    % --- normalize identifiers -------------------------------------------
    element_id = local_id(element);
    neuron_ids = local_ids(neuron_ids);

    if numel(neuron_names)~=numel(neuron_ids)
        error('ndi:ensemble:create:nameCountMismatch', ...
            ['NEURON_NAMES has %d entries but NEURON_IDS has %d; there must ' ...
            'be one name per neuron.'], numel(neuron_names), numel(neuron_ids));
    end

    % --- write the activity to a temporary sparse file -------------------
    activity_tempfile = [ndi.file.temp_name() '.ndisparse'];
    if isstruct(activity)
        if ~all(isfield(activity, {'subs','vals','size'}))
            error('ndi:ensemble:create:badActivityStruct', ...
                ['When ACTIVITY is a struct it must have fields ''subs'', ' ...
                '''vals'', and ''size''.']);
        end
        ndi.util.writeSparse(activity_tempfile, activity.subs, activity.vals, activity.size);
        num_dimensions = numel(activity.size);
    else
        if ~ismatrix(activity) || (~isnumeric(activity) && ~islogical(activity))
            error('ndi:ensemble:create:badActivity', ...
                ['ACTIVITY must be a 2-D numeric/logical matrix or a struct ' ...
                'with fields ''subs'', ''vals'', and ''size''.']);
        end
        if size(activity,1)~=numel(neuron_ids)
            warning('ndi:ensemble:create:rowCountMismatch', ...
                ['ACTIVITY has %d rows but there are %d neurons; row i is ' ...
                'expected to correspond to neuron i.'], ...
                size(activity,1), numel(neuron_ids));
        end
        ndi.util.writeSparse(activity_tempfile, activity);
        num_dimensions = 2;
    end

    % --- write the neuron names to a temporary text file -----------------
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

    % --- application provenance ------------------------------------------
    app_version = '';
    try
        app_version = ndi.version();
    catch
    end

    % --- build the document ----------------------------------------------
    ensemble_doc = S.newdocument('ensemble', ...
        'ensemble.ensemble_name', options.ensemble_name, ...
        'ensemble.value_type', options.value_type, ...
        'ensemble.value_description', options.value_description, ...
        'ensemble.num_neurons', numel(neuron_ids), ...
        'ensemble.num_dimensions', num_dimensions, ...
        'ensemble.clocktype', options.clocktype, ...
        'epochid.epochid', options.epochid, ...
        'app.name', 'ndi.ensemble', ...
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
        S.database_add(ensemble_doc);
    end

end % create()

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

function ids = local_ids(c)
% map a cell array of ids/objects to a cell array of char ids
    ids = cell(1, numel(c));
    for i=1:numel(c)
        ids{i} = local_id(c{i});
    end
end % local_ids()
