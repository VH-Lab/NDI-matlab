function ids = edgeTargets(doc, name)
%EDGETARGETS The targets of a document's edges named NAME, as a search matches them.
%
%   IDS = ndi.vintage.edgeTargets(DOC, NAME) is a cellstr of the targets of
%   every `depends_on` entry of DOC (an ndi.document or a struct of document
%   properties) whose name is exactly NAME, read from `document_id`, `value`
%   or `id`. It is the test did2's `depends_on` applies (did2.query
%   opDependsOn: the exact name, any of those keys), so a list filtered by it
%   in memory holds what a search with that edge would have returned. Unlike
%   ndi.v2.edgeIds it does not read the numbered names (`name_1`, ...), and
%   unlike dependency_value it does not stop at the first entry.
%
%   See also ndi.vintage.edgeIn, ndi.v2.edgeIds.

arguments
    doc
    name (1,:) char
end

ids = {};
p = ndi.v2.props(doc);
if ~isfield(p, 'depends_on') || isempty(p.depends_on)
    return;
end
dep = p.depends_on;
if isstruct(dep), dep = num2cell(dep); end
for k = 1:numel(dep)
    e = dep{k};
    if ~isstruct(e) || ~isfield(e, 'name') || ~strcmp(char(e.name), name)
        continue;
    end
    if isfield(e, 'document_id')
        v = e.document_id;
    elseif isfield(e, 'value')
        v = e.value;
    elseif isfield(e, 'id')
        v = e.id;
    else
        continue;
    end
    if ischar(v) || (isstring(v) && isscalar(v))
        ids{end+1} = char(v); %#ok<AGROW>
    end
end
end
