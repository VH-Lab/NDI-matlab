function ids = mintedIdSet(docs)
%MINTEDIDSET The sorted, unique base.id values of DOCS.
%
%   IDS = ndi.unittest.migrate.mintedIdSet(DOCS), DOCS a cell array of
%   document bodies (structs, JSON text, or did2.document / ndi.document
%   objects), returns their `base.id` values as a sorted 1xN cellstr with
%   duplicates removed. An entry with no id is skipped.
%
%   For the determinism checks of [migration reliability practices] (b)
%   (Jess Haley, 2026-10-26, did-schema did_v2_go_forward_class_audit.md):
%   "two runs on the same input are identical and can be diffed". Two runs
%   of a second-pass step (or of ndi.migrate.local) over the same input
%   must give equal sets.
%
%   See also ndi.migrate.internal.withMintSource, did2.convert.mintId.

ids = {};
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
    if isstruct(d) && isscalar(d) && isfield(d, 'base') && isstruct(d.base) ...
            && isfield(d.base, 'id') && ~isempty(d.base.id)
        ids{end+1} = char(d.base.id); %#ok<AGROW>
    end
end
ids = unique(ids);
ids = reshape(ids, 1, []);
end
