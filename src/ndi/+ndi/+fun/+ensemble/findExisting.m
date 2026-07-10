function docs = findExisting(S, element_id, neuron_ids, neuron_names, options)
% ndi.fun.ensemble.findExisting - find ensemble documents matching an ensemble
%
% DOCS = ndi.fun.ensemble.FINDEXISTING(S, ELEMENT_ID, NEURON_IDS, NEURON_NAMES, ...)
%
% Searches the ndi.session (or ndi.dataset) S for 'ensemble' documents that
% describe the same ensemble: the same owning element (ELEMENT_ID dependency),
% the same neuron elements (NEURON_IDS, the neuron_id_# dependencies, in the
% same order), and the same neuron names (NEURON_NAMES, the contents of the
% neuron_names.txt file). DOCS is a cell array of the matching ndi.document
% objects (empty if none match).
%
% This is used by ndi.fun.ensemble.create to avoid storing a duplicate
% ensemble.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   epochid ('')  - if non-empty, a candidate must also have this epoch id
%                   (epochid.epochid) to be considered a match. This keeps
%                   ensembles built for different epochs from being treated as
%                   duplicates of one another.
%
% See also: ndi.fun.ensemble.create

    arguments
        S
        element_id (1,:) char
        neuron_ids cell
        neuron_names cell
        options.epochid (1,:) char = ''
    end

    docs = {};
    want_ids = neuron_ids(:).';
    want_names = neuron_names(:).';

    candidates = S.database_search(ndi.query('','isa','ensemble',''));
    for i = 1:numel(candidates)
        c = candidates{i};

        % same owning element?
        if ~strcmp(local_dep(c,'element_id'), element_id)
            continue;
        end

        % same epoch (if requested)?
        if ~isempty(options.epochid)
            if ~isfield(c.document_properties,'epochid') || ...
                    ~strcmp(c.document_properties.epochid.epochid, options.epochid)
                continue;
            end
        end

        % same neuron ids, in the same order?
        cids = c.dependency_value_n('neuron_id','ErrorIfNotFound',0);
        if ~isequal(cids(:).', want_ids)
            continue;
        end

        % same neuron names?
        cnames = local_read_names(S, c);
        if isequal(cnames(:).', want_names)
            docs{end+1} = c; %#ok<AGROW>
        end
    end

end % findExisting()

% -------------------------------------------------------------------------

function v = local_dep(doc, name)
    v = doc.dependency_value(name, 'ErrorIfNotFound', 0);
    if isempty(v)
        v = '';
    end
end % local_dep()

function names = local_read_names(S, doc)
% read the neuron_names.txt of an ensemble document into a cell array of lines
    names = {};
    tempfile = ndi.database.fun.copydocfile2temp(doc, S, 'neuron_names.txt', '.txt');
    cleanup = onCleanup(@() local_delete(tempfile)); %#ok<NASGU>
    txt = fileread(tempfile);
    if isempty(txt)
        return;
    end
    lines = regexp(txt, '\r\n|\r|\n', 'split');
    if ~isempty(lines) && isempty(lines{end})
        lines(end) = [];
    end
    names = lines(:).';
end % local_read_names()

function local_delete(filename)
    if exist(filename, 'file')
        delete(filename);
    end
end % local_delete()
