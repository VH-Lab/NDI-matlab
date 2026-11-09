function ids = edgeIds(p, name)
%EDGEIDS The document ids a document's NAME edge points at.
%
%   IDS = ndi.v2.edgeIds(P, NAME) returns a cellstr (row), in order: every
%   depends_on entry called NAME (a v2 edge may repeat its name) or NAME_<n>
%   (the v1 numbered form). Empty values are left out. A v2 edge holds the
%   id in `document_id`, a v1 edge in `value`.

arguments
    p
    name {mustBeText}
end

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
    % NAME, or NAME_<digits> (as regexp '^NAME_\d+$' matches), tested
    % without a regular expression: this runs once per edge of every
    % statement an epoch table reads (15,310 calls, 0.95 s self in
    % NDI-matlab run 42342493540, profiled)
    if ~strcmp(n, name)
        k = numel(name) + 1;
        if numel(n) <= k || ~strncmp(n, [name '_'], k) || any(n(k+1:end) < '0' | n(k+1:end) > '9')
            continue;
        end
    end
    v = '';
    if isfield(e, 'document_id'), v = e.document_id; elseif isfield(e, 'value'), v = e.value; end
    v = char(v);
    if ~isempty(v), ids{end+1} = v; end %#ok<AGROW>
end
if isempty(ids) && strcmp(name, 'entity_id')
    % a statement written before 2026-10-08 names what it is about `subject_id`
    ids = ndi.v2.edgeIds(p, 'subject_id');
end
end
