function ids = elementAssertionIds(ndi_session_obj, classFilter)
%ELEMENTASSERTIONIDS The entities an "ndi element class" assertion is about.
%
%   IDS = ndi.vintage.elementAssertionIds(SESSION) is a cellstr of the ids
%   (first-seen order, no repeats) of the entities a term assertion labelled
%   `ndi element class` (ndi.vintage.elementLabel('class')) is about;
%   IDS = ndi.vintage.elementAssertionIds(SESSION, CLASSFILTER) only those
%   whose value contains CLASSFILTER. Read for their entity edge only where
%   the database can (ndi.vintage.edgeDocs). The unfiltered answer is kept
%   for a call's scope (ndi.vintage.elementFieldsScope).
%
%   While the assertion is written it decides an element's class (Decided by
%   Jess Haley, 2026-11-10 [assertion wins while written]), so
%   ndi.vintage.linkedElements asks about the links of the other entities only.
%
%   See also ndi.vintage.elementSubjectIds, ndi.vintage.linkedElements.

arguments
    ndi_session_obj
    classFilter (1,:) char = ''
end
% Inside a call's scope the assertions are read ONCE, unfiltered, with each
% one's class (its entity edge and term.value name, from the database's
% indexes where it can), and every list of the call (getprobes' filtered
% one, ndi.vintage.linkedElements' unfiltered one) is taken from them.
if ndi.vintage.elementFieldsScope('isopen')
    key = '';
    try
        key = ['A|' char(ndi_session_obj.id())];
    catch
    end
    if ~isempty(key)
        [A, hit] = ndi.vintage.elementFieldsScope('get', key);
        if ~hit
            A = readAll(ndi_session_obj);
            ndi.vintage.elementFieldsScope('put', key, A);
        end
        if isstruct(A)
            keep = true(1, numel(A.entity));
            if ~isempty(classFilter)
                keep = contains(A.class, classFilter);
            end
            ids = firstSeen(A.entity(keep));
            return;
        end
    end
end
ids = {};
label = ndi.vintage.elementLabel('class');
q = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', label);
if ~isempty(classFilter)
    q = q & ndi.query('term.value.name', 'contains_string', classFilter, '');
end

% read for their entity edge only (ndi.vintage.edgeDocs), else the documents
assertions = ndi.vintage.edgeDocs(ndi_session_obj, q, {'entity_id', 'subject_id'}, 'assertion');
if ~iscell(assertions)
    assertions = ndi_session_obj.database_search(q);
end

% Collect the subject ids, keeping FIRST-SEEN order. `unique` would sort,
% and the caller's order would then depend on how ids happen to compare
% rather than on anything meaningful.
for i = 1:numel(assertions)
    sid = ndi.v2.edgeIds(ndi.v2.props(assertions{i}), 'entity_id');
    if isempty(sid), sid = ''; else, sid = sid{1}; end
    if isempty(sid) || any(strcmp(sid, ids))
        continue;
    end
    ids{end+1} = sid; %#ok<AGROW>
end

end

function A = readAll(S)
% every class assertion's entity and class, in the database's order; []
% when the database cannot answer from its indexes (the caller then
% searches as before)
A = [];
if ~ismethod(S, 'database_search_values') || ~ismethod(S, 'database_search_edges')
    return;
end
q = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', ndi.vintage.elementLabel('class'));
vals = S.database_search_values(q, {'term.value[*].name'});
if ~isstruct(vals)
    return;
end
edges = S.database_search_edges(q, {'entity_id'});
if ~isstruct(edges)
    return;
end
firstE = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(edges)
    d = edges(k).doc_id;
    if strcmp(edges(k).name, 'entity_id') && ~isKey(firstE, d)
        firstE(d) = edges(k).document_id;
    end
end
ent = cell(1, numel(vals));
cls = cell(1, numel(vals));
for k = 1:numel(vals)
    d = vals(k).doc_id;
    e = '';
    if isKey(firstE, d); e = firstE(d); end   % entity_id, as the search below reads it
    ent{k} = e;
    cls{k} = char(vals(k).values{1});
end
A = struct('entity', {ent}, 'class', {cls});
end

function ids = firstSeen(c)
ids = {};
for k = 1:numel(c)
    if ~isempty(c{k}) && ~any(strcmp(c{k}, ids))
        ids{end+1} = c{k}; %#ok<AGROW>
    end
end
end
