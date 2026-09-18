function docs = findExisting(S, ensembleElement, options)
% ndi.fun.ensemble.findExisting - find the ensemble map documents of an ensemble element
%
% DOCS = ndi.fun.ensemble.FINDEXISTING(S, ENSEMBLEELEMENT, ...)
%
% Returns the 'ensemble' map documents that belong to ENSEMBLEELEMENT (an
% ndi.element.ensemble object or its element document id) in the ndi.session (or
% ndi.dataset) S. Optionally restrict to a single epoch. DOCS is a cell array of
% the matching ndi.document objects (empty if none).
%
% This is used by ndi.fun.ensemble.create and ndi.fun.ensemble.allElement to
% detect whether an ensemble already exists for a given element and epoch.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   epochid ('')  - if non-empty, return only the map document for this epoch.
%
% See also: ndi.fun.ensemble.create, ndi.element.ensemble

    arguments
        S
        ensembleElement
        options.epochid (1,:) char = ''
    end

    if isa(ensembleElement,'ndi.element')
        element_id = ensembleElement.id();
    elseif ischar(ensembleElement) || (isstring(ensembleElement) && isscalar(ensembleElement))
        element_id = char(ensembleElement);
    else
        error('ndi:ensemble:findExisting:badElement', ...
            'ENSEMBLEELEMENT must be an ndi.element.ensemble object or a document id string.');
    end

    sq = ndi.query('','isa','ensemble','') & ...
        ndi.query('','depends_on','element_id', element_id);
    if ~isempty(options.epochid)
        sq = sq & ndi.query('epochid.epochid','exact_string', options.epochid, '');
    end

    docs = S.database_search(sq);

end % findExisting()
