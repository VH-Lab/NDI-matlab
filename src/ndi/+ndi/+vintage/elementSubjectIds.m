function [ids, label] = elementSubjectIds(ndi_session_obj, classFilter)
%ELEMENTSUBJECTIDS The ids of the v2 entities that are elements.
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
%   BY THEIR LINKS, TOO (Decided by Jess Haley, 2026-11-10 [element
%   recognised by its links], [ensemble has members]; did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): the entities
%   ndi.vintage.linkedElements finds -- a `device` with a recording
%   observation or a wiring relation (a probe), a `cell` or `Group` with a
%   `derived_from` relation onto such a probe (a sorted unit; a Group with
%   members is an ensemble) -- follow the assertion ones, in the order their
%   links were found. The assertion is kept as a fallback where present, so
%   every element migrated before DID-matlab stops writing it is still found
%   in the same order. With CLASSFILTER, a linked element is kept when the
%   class rebuilt from its kind contains it ('ndi.probe...' for a probe,
%   'ndi.neuron' for a unit, 'ndi.element.ensemble' for an ensemble), and
%   an element whose rebuilt kind does not match is dropped even when its
%   assertion does (the rebuilt class wins: Proposed, not decided).
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.subjectDocs,
%             ndi.vintage.linkedElements.

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

% the elements recognised by their links ([element recognised by its links])
L = ndi.vintage.linkedElements(ndi_session_obj);
if ~isempty(classFilter)
    known = isKey(L.kind, ids);
    keep = true(1, numel(ids));
    for k = find(known)
        keep(k) = contains(classStem(L.kind(ids{k})), classFilter);
    end
    ids = ids(keep);
end
for k = 1:numel(L.ids)
    id = L.ids{k};
    if any(strcmp(id, ids))
        continue;
    end
    if ~isempty(classFilter) && ~contains(classStem(L.kind(id)), classFilter)
        continue;
    end
    ids{end+1} = id; %#ok<AGROW>
end
end

function s = classStem(kind)
% what the class rebuilt for KIND starts with (ndi.vintage.elementClassOfKind):
% every class probetype2object.json names is an ndi.probe.* class
switch kind
    case 'probe'
        s = 'ndi.probe.';
    case 'unit'
        s = 'ndi.neuron';
    case 'ensemble'
        s = 'ndi.element.ensemble';
    otherwise
        s = '';
end
end
