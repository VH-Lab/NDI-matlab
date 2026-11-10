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
key = '';
if isempty(classFilter) && ndi.vintage.elementFieldsScope('isopen')
    try
        key = ['A|' char(ndi_session_obj.id())];
    catch
        key = '';
    end
    if ~isempty(key)
        [ids, hit] = ndi.vintage.elementFieldsScope('get', key);
        if hit; return; end
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

if ~isempty(key)
    ndi.vintage.elementFieldsScope('put', key, ids);
end
end
