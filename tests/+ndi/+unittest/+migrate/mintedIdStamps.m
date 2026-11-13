function rows = mintedIdStamps(docs)
%MINTEDIDSTAMPS Each document's id with its timestamp, sorted, for comparing
%   the VALUES two runs gave, not only their ids.
%
%   ROWS = ndi.unittest.migrate.mintedIdStamps(DOCS), DOCS a cell array of
%   document bodies (structs, JSON text, or did2.document / ndi.document
%   objects), returns a sorted 1xN cellstr of '<base.id> <timestamp>' rows,
%   duplicates removed. The timestamp is base.creation_timestamp (v2), else
%   base.datestamp (v1), else empty. An entry with no id is skipped.
%
%   For the determinism checks of [migration reliability practices] (b)
%   (Jess Haley, 2026-10-26, did-schema did_v2_go_forward_class_audit.md):
%   "two runs on the same input are identical and can be diffed". A value
%   taken from the document read first (NDI-matlab #1235: database order is
%   not data) gives the same ids in two read orders but different rows here.
%
%   See also ndi.unittest.migrate.mintedIdSet,
%   ndi.migrate.internal.earliestByContent.

rows = {};
if isstruct(docs)
    docs = num2cell(docs);
end
for k = 1:numel(docs)
    d = docs{k};
    if isstring(d) || ischar(d)
        try
            d = jsondecode(char(d));
        catch
            continue;
        end
    elseif isobject(d)
        try
            if isprop(d, 'document_properties')
                d = d.document_properties;
            else
                d = d.toStruct();
            end
        catch
            continue;
        end
    end
    if ~(isstruct(d) && isscalar(d) && isfield(d, 'base') && isstruct(d.base) ...
            && isfield(d.base, 'id') && ~isempty(d.base.id))
        continue;
    end
    stamp = '';
    if isfield(d.base, 'creation_timestamp') && ~isempty(d.base.creation_timestamp)
        stamp = char(d.base.creation_timestamp);
    elseif isfield(d.base, 'datestamp') && ~isempty(d.base.datestamp)
        stamp = char(d.base.datestamp);
    end
    rows{end+1} = [char(d.base.id) ' ' stamp]; %#ok<AGROW>
end
rows = unique(rows);
rows = reshape(rows, 1, []);
end
