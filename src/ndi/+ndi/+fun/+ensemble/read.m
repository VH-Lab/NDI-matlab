function [activity, neuron_ids, neuron_names, element_id, info] = read(S, ensemble_doc)
% ndi.fun.ensemble.read - read the contents of an 'ensemble' ndi.document
%
% [ACTIVITY, NEURON_IDS, NEURON_NAMES, ELEMENT_ID, INFO] = ndi.fun.ensemble.READ(S, ENSEMBLE_DOC)
%
% Reads back the data stored by ndi.fun.ensemble.create in an 'ensemble'
% ndi.document ENSEMBLE_DOC that belongs to the ndi.session or ndi.dataset S.
%
% =========================================================================
% OUTPUTS
% =========================================================================
%   ACTIVITY     - the ensemble activity. If the stored array is 2-D, this is
%                  a MATLAB sparse matrix (e.g. an N-by-Smax matrix of spike
%                  times). If it is N-dimensional (N>2), it is a struct with
%                  fields 'subs' (1-based), 'vals', and 'size' (see
%                  ndi.util.readSparse).
%   NEURON_IDS   - a 1-by-N cell array of the neuron element document ids
%                  (from the 'neuron_id_#' dependencies). NEURON_IDS{i}
%                  corresponds to row i of ACTIVITY.
%   NEURON_NAMES - a 1-by-N cell array of the neuron names (the lines of the
%                  document's neuron_names.txt file).
%   ELEMENT_ID   - the document id of the element (probe) the ensemble belongs
%                  to (the 'element_id' dependency).
%   INFO         - the document's 'ensemble' property structure (ensemble_name,
%                  value_type, value_description, num_neurons, num_dimensions,
%                  clocktype).
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   docs = S.database_search(ndi.query('','isa','ensemble',''));
%   [E, neuron_ids, neuron_names, element_id, info] = ndi.fun.ensemble.read(S, docs{1});
%
% See also: ndi.fun.ensemble.create, ndi.util.readSparse

    arguments
        S
        ensemble_doc (1,1) ndi.document
    end

    % --- dependencies -----------------------------------------------------
    element_id = ensemble_doc.dependency_value('element_id');
    neuron_ids = ensemble_doc.dependency_value_n('neuron_id', 'ErrorIfNotFound', 0);
    neuron_ids = neuron_ids(:).';

    % --- property structure ----------------------------------------------
    info = ensemble_doc.document_properties.ensemble;

    % --- read the activity binary file -----------------------------------
    activity_tempfile = ndi.database.fun.copydocfile2temp(ensemble_doc, S, ...
        'ensemble_activity.ndisparse', '.ndisparse');
    cleanup_activity = onCleanup(@() local_delete(activity_tempfile)); %#ok<NASGU>
    activity = ndi.util.readSparse(activity_tempfile);

    % --- read the neuron names text file ---------------------------------
    names_tempfile = ndi.database.fun.copydocfile2temp(ensemble_doc, S, ...
        'neuron_names.txt', '.txt');
    cleanup_names = onCleanup(@() local_delete(names_tempfile)); %#ok<NASGU>
    neuron_names = local_readlines(names_tempfile);

end % read()

% -------------------------------------------------------------------------

function names = local_readlines(filename)
% read a text file into a 1-by-N cell array of lines (no trailing newline)
    txt = fileread(filename);
    if isempty(txt)
        names = {};
        return;
    end
    % split on any newline convention; drop a single trailing empty line
    lines = regexp(txt, '\r\n|\r|\n', 'split');
    if ~isempty(lines) && isempty(lines{end})
        lines(end) = [];
    end
    names = lines(:).';
end % local_readlines()

function local_delete(filename)
    if exist(filename, 'file')
        delete(filename);
    end
end % local_delete()
