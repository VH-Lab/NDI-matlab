function ids = edgeIds(p, name)
%EDGEIDS The document ids a document's NAME edge points at.
%
%   IDS = ndi.v2.edgeIds(P, NAME) returns a cellstr (row), in order: every
%   depends_on entry called NAME (a V2 edge may repeat its name) or NAME_<n>
%   (the v1 numbered form). Empty values are left out. A V2 edge holds the
%   id in `document_id`, a v1 edge in `value`.

ids = {};
if ~isfield(p, 'depends_on') || isempty(p.depends_on)
    return;
end
dep = p.depends_on;
if isstruct(dep), dep = num2cell(dep); end
for k = 1:numel(dep)
    e = dep{k};
    if ~isfield(e, 'name'), continue; end
    n = char(e.name);
    if ~(strcmp(n, name) || ~isempty(regexp(n, ['^' regexptranslate('escape', name) '_\d+$'], 'once')))
        continue;
    end
    v = '';
    if isfield(e, 'document_id'), v = e.document_id; elseif isfield(e, 'value'), v = e.value; end
    v = char(v);
    if ~isempty(v), ids{end+1} = v; end %#ok<AGROW>
end
end
