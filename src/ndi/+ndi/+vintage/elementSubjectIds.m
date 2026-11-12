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
%   in the same order. With CLASSFILTER, an element with the assertion is
%   kept by its assertion's class (the assertion wins while it is written:
%   Decided by Jess Haley, 2026-11-10 [assertion wins while written]), and a linked element with none is
%   kept when the class rebuilt from its kind contains it ('ndi.probe...'
%   for a probe, 'ndi.neuron' for a unit, 'ndi.element.ensemble' for an
%   ensemble).
%
%   See also: ndi.vintage.elementSubjectDocs, ndi.vintage.subjectDocs,
%             ndi.vintage.linkedElements.

arguments
    ndi_session_obj
    classFilter (1,:) char = ''
end

ids = ndi.vintage.elementAssertionIds(ndi_session_obj, classFilter);
label = ndi.vintage.elementLabel('class');

% the elements recognised by their links ([element recognised by its links])
L = ndi.vintage.linkedElements(ndi_session_obj);
% (only entities no class assertion is about: while it is written the
% assertion decides, [assertion wins while written])
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
