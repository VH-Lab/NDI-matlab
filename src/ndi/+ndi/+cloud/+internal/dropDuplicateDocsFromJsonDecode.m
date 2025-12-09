function docsOut = dropDuplicateDocsFromJsonDecode(docsIn)
% DROPDUPLICATEDOCSFROMJSONDECODE - examine a document struct or cell array for duplicates
%
% DOCSOUT = ndi.cloud.internal.dropDuplicateDocsFromJsonDecode(DOCSIN);
%
% Given a DOCSIN that is computed internally from
%   ndi.cloud.download.downloadDocumentCollection, remove duplicates.
%
% DOCSIN can be a structure array or a cell array of structures.
% DOCSOUT will be of the same type as DOCSIN.
%

    arguments
        docsIn
    end

    if isempty(docsIn)
        docsOut = docsIn;
        return;
    end

    isCell = iscell(docsIn);

    if ~isstruct(docsIn) && ~isCell
        error('Input must be a struct array or a cell array of structs.');
    end

    numDocs = numel(docsIn);
    ids = cell(numDocs, 1);

    for i = 1:numDocs
        if isCell
            doc = docsIn{i};
        else
            doc = docsIn(i);
        end

        if isfield(doc, 'base') && isfield(doc.base, 'id')
             ids{i} = doc.base.id;
        else
            % Handle case where structure might not be completely formed or lacks ID
            % This shouldn't happen for valid NDI documents but good for robustness
            ids{i} = '';
        end
    end

    % Find unique IDs
    % We want to preserve the first occurrence or use unique's behavior.
    % The original implementation used [~, indexes] = unique(ids), which sorts by default.
    % 'stable' preserves order of appearance.
    [~, indexes] = unique(ids, 'stable');

    if isCell
        docsOut = docsIn(indexes);
    else
        docsOut = docsIn(indexes);
    end
end
