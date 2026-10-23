function report = dimensionTermCensus(docs)
%DIMENSIONTERMCENSUS Count the dimensions written whose term has no node.
%
%   REPORT = ndi.migrate.internal.dimensionTermCensus(DOCS) reads every
%   document in DOCS (a cell of did2.document objects or body structs) and
%   counts the entries of its value's `data.dimensions` (did-schema
%   V_eta_data_body_model_plan.md AMENDMENT 6) and, among them, those whose
%   `term` carries no ontology node: a label {name} with an empty or missing
%   `node`, or a bare name.
%
%   Decided by Jess Haley, 2026-10-22 [covariate details], answer "B" to 5.4:
%   a dimension's term is bound `preferred`, and each corpus report counts the
%   dimensions whose term has no node, so dimension terms can move to
%   `required` with the variable bindings under OPEN_WORK #129 after the merge.
%
%   REPORT (denominators first, unconditionally):
%     documents_inspected        numel(DOCS)
%     documents_with_dimensions  documents carrying at least one dimension
%     dimensions_written         dimension entries over all documents (THE
%                                denominator of the next count)
%     dimensions_without_node    of those, the ones whose term has no node
%     without_node_by_term       struct array {name, class_name, count}: the
%                                term names (and document classes) that have
%                                no node, most frequent first
%     unreadable_documents       documents that could not be read as a struct
%
%   See also ndi.migrate.local.

report = struct( ...
    'documents_inspected',       numel(docs), ...
    'documents_with_dimensions', 0, ...
    'dimensions_written',        0, ...
    'dimensions_without_node',   0, ...
    'without_node_by_term',      struct('name', {}, 'class_name', {}, 'count', {}), ...
    'unreadable_documents',      0);
tally = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(docs)
    s = docs{k};
    try
        if ~isstruct(s)
            s = s.toStruct();
        end
    catch
        report.unreadable_documents = report.unreadable_documents + 1;
        continue;
    end
    if ~isstruct(s) || ~isfield(s, 'data') || ~isstruct(s.data) || ~isscalar(s.data) ...
            || ~isfield(s.data, 'dimensions') || isempty(s.data.dimensions)
        continue;
    end
    dims = ndi.v2.entries(s.data.dimensions);
    if isempty(dims)
        continue;
    end
    report.documents_with_dimensions = report.documents_with_dimensions + 1;
    cls = '';
    if isfield(s, 'document_class') && isstruct(s.document_class) ...
            && isfield(s.document_class, 'class_name')
        cls = char(s.document_class.class_name);
    end
    for j = 1:numel(dims)
        report.dimensions_written = report.dimensions_written + 1;
        [hasNode, name] = termNode(dims{j});
        if hasNode
            continue;
        end
        report.dimensions_without_node = report.dimensions_without_node + 1;
        key = [name char(0) cls];
        if isKey(tally, key)
            tally(key) = tally(key) + 1;
        else
            tally(key) = 1;
        end
    end
end
keys_ = tally.keys();
rows = struct('name', {}, 'class_name', {}, 'count', {});
for i = 1:numel(keys_)
    parts = strsplit(keys_{i}, char(0));
    if numel(parts) < 2
        parts{2} = '';
    end
    rows(end+1) = struct('name', parts{1}, 'class_name', parts{2}, ...
        'count', tally(keys_{i})); %#ok<AGROW>
end
if ~isempty(rows)
    [~, order] = sort(-[rows.count]);
    rows = rows(order);
end
report.without_node_by_term = rows;
end

function [hasNode, name] = termNode(dim)
hasNode = false;
name = '(no term)';
if ~isstruct(dim) || ~isfield(dim, 'term')
    return;
end
t = dim.term;
if iscell(t) && ~isempty(t)
    t = t{1};
end
if ischar(t) || (isstring(t) && isscalar(t))
    name = char(t);
    return;
end
if ~isstruct(t) || isempty(t)
    return;
end
t = t(1);
if isfield(t, 'name') && ~isempty(t.name)
    name = char(t.name);
end
hasNode = isfield(t, 'node') && ~isempty(t.node) && ~isempty(strtrim(char(t.node)));
end
