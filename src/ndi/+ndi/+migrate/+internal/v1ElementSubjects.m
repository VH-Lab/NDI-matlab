function [subjects, report] = v1ElementSubjects(v1Bodies)
%V1ELEMENTSUBJECTS The v1 subject of every direct element the migration input holds.
%
%   [SUBJECTS, REPORT] = ndi.migrate.internal.v1ElementSubjects(V1BODIES)
%   reads the v1 `element` documents of V1BODIES (a cell of JSON text or
%   decoded structs: the migration input) and returns SUBJECTS, a
%   containers.Map from each element's base.id to the id its
%   `depends_on subject_id` names, for every element that is direct
%   (`element.direct` true) with a subject and no `underlying_element_id`:
%   the elements DID-matlab's +migrators_j/element.m wrote an `observes`
%   relation for until [no observes relation in v2].
%
%   Decided by Jess Haley, 2026-11-26 [no observes relation in v2] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md): v2 has no `observes`
%   relation; "NDI's second pass reads the v1 `subject_id` directly; the
%   animal is the `entity_id` of the observations and manipulations made
%   with the element, or, where none names it, is carried as the element's
%   subject". This is that read. A sorted unit or derived element (an
%   underlying element, or `direct` false) is not listed: its subject is
%   its lineage's (`derived_from`), not this decision's.
%
%   An id two v1 elements share with different subjects is not listed
%   (REPORT.conflicting): which subject is the element's is not this pass's
%   to choose.
%
%   REPORT (the denominator first): bodies_read, elements, direct_with_subject
%   (= SUBJECTS.Count), not_direct, no_subject, with_underlying, conflicting.
%
%   See also ndi.migrate.internal.observesRetirement,
%   ndi.migrate.internal.recordingAttribution, ndi.migrate.local.

subjects = containers.Map('KeyType', 'char', 'ValueType', 'char');
report = struct('bodies_read', numel(v1Bodies), 'elements', 0, ...
    'direct_with_subject', 0, 'not_direct', 0, 'no_subject', 0, ...
    'with_underlying', 0, 'conflicting', 0);
S = ndi.migrate.internal.etaShape;
conflicted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(v1Bodies)
    b = v1Bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        b = char(b);
        if ~contains(b, '"element"')
            continue;
        end
        try
            b = jsondecode(b);
        catch
            continue;
        end
    end
    if ~isstruct(b) || ~isscalar(b) || ~strcmp(S.className(b), 'element') ...
            || ~isfield(b, 'base') || ~isfield(b.base, 'id') || isempty(b.base.id)
        continue;
    end
    if isfield(b, 'depends_on') && iscell(b.depends_on)
        try
            b.depends_on = [b.depends_on{:}];
        catch
            continue;
        end
    end
    report.elements = report.elements + 1;
    id = char(b.base.id);
    if ~isempty(S.edge(b, 'underlying_element_id'))
        report.with_underlying = report.with_underlying + 1;
        continue;
    end
    direct = [];
    if isfield(b, 'element') && isstruct(b.element) && isfield(b.element, 'direct')
        direct = b.element.direct;
    end
    if ~isTruthy(direct)
        report.not_direct = report.not_direct + 1;
        continue;
    end
    subject = S.edge(b, 'subject_id');
    if isempty(subject)
        report.no_subject = report.no_subject + 1;
        continue;
    end
    if isKey(conflicted, id)
        continue;
    end
    if isKey(subjects, id)
        if ~strcmp(subjects(id), subject)
            remove(subjects, id);
            conflicted(id) = true;
        end
        continue;
    end
    subjects(id) = subject;
end
report.conflicting = double(conflicted.Count);
report.direct_with_subject = double(subjects.Count);
end

function tf = isTruthy(v)
% as DID-matlab's +migrators_j/element.m reads `element.direct`
tf = false;
if islogical(v) && ~isempty(v)
    tf = v(1);
elseif isnumeric(v) && ~isempty(v)
    tf = v(1) ~= 0;
elseif ischar(v) || (isstring(v) && isscalar(v))
    tf = any(strcmpi(strtrim(char(v)), {'1', 'true', 'yes'}));
end
end
