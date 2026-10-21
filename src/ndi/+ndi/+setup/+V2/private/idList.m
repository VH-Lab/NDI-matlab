function ids = idList(v)
%IDLIST A list of document ids, however a table cell happens to hold it.
%
%   IDS = idList(V) returns V as a 1xN cellstr. V may be '' or [] (no ids),
%   one id as char or string, a string array, a cellstr, or a cell holding any
%   of these -- including the one-element cell that cell2table and
%   struct2table unwrap to plain char when a column holds a single id per
%   row. Every reader of a session's `study_ids` goes through here
%   (ndi.setup.V2.createSession, ndi.setup.V2.writeDataset), so a table built
%   either way gives the same relations.

arguments
    v
end
ids = {};
if isempty(v)
    return;
end
if ischar(v)
    ids = {v};
elseif isstring(v)
    v = v(~ismissing(v));
    ids = reshape(cellstr(v), 1, []);
elseif iscell(v)
    for k = 1:numel(v)
        ids = [ids, idList(v{k})]; %#ok<AGROW>
    end
else
    error('ndi:setup:V2:badIdList', 'An id list holds %s, not text.', class(v));
end
ids = ids(~cellfun(@isempty, ids));
end
