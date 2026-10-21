function [ids, label] = elementSubjectIds(ndi_session_obj, classFilter)
%ELEMENTSUBJECTIDS The ids of the subject documents that used to be elements.
%
%   IDS = ndi.vintage.elementSubjectIds(NDI_SESSION_OBJ)
%   IDS = ndi.vintage.elementSubjectIds(NDI_SESSION_OBJ, CLASSFILTER)
%   [IDS, LABEL] = ndi.vintage.elementSubjectIds(...)
%
%   Step 1 of ndi.vintage.elementSubjectDocs, on its own: the `subject_id`
%   edges (first-seen order, no repeats) of the term_assertions labelled
%   `ndi element class` (ndi.vintage.elementLabel('class')), optionally
%   only those whose value contains CLASSFILTER. It does not fetch the
%   subjects, so a caller that only needs to know WHICH subjects are
%   apparatus (ndi.vintage.subjectDocs) makes one query, not one per
%   element. LABEL is the assertion label searched for.
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.subjectDocs.

arguments
    ndi_session_obj
    classFilter (1,:) char = ''
end

ids = {};

label = ndi.vintage.elementLabel('class');
q = ndi.v2.statementQuery('assertion', 'term') & ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', label);
if ~isempty(classFilter)
    q = q & ndi.query('term.value.name', 'contains_string', classFilter, '');
end

assertions = ndi_session_obj.database_search(q);

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
