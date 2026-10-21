function docs = subjectDocs(ndi_session_obj)
%SUBJECTDOCS The biological subject documents of a session or dataset, any vintage.
%
%   DOCS = ndi.vintage.subjectDocs(NDI_SESSION_OBJ) returns a cell array of
%   ndi.document: the subjects as a v1 session has them -- organisms,
%   cultures, tissues, cells and groups -- and not the apparatus. It is what
%   ndi.session/getsubjects and ndi.dataset/getsubjects return (Jess Haley,
%   2026-10-21: "for V2 datasets, getsubjects should return only biological
%   entities to match V1 dataset behavior").
%
%   THREE SHAPES, ONE ANSWER:
%     v1        `subject` documents are the animals; no device is ever a
%               `subject`. `isa subject` is the answer.
%     V2        (a subject or entity with a `type`) ndi.query's own
%               `isa subject` already keeps only ndi.v2.subjectTypes(), so
%               a probe (device) or a plate (material) is left out there.
%     migrated  (V_eta before subjects had a type) a v1 `element` became a
%               `subject` with NO type, indistinguishable from the animal
%               by class or field; what marks it is an inbound
%               `ndi element class` term_assertion. Those subjects are
%               removed here (ndi.vintage.elementSubjectIds), so migrated
%               PRED's animal + 2 probes reads as 1 subject, as it did in v1.
%   The element subtraction runs only when some subject found carries no
%   type, which is exactly the v1 and pre-type migrated case; on v1 it
%   finds no assertion and removes nothing (getelements runs the same
%   query on every session).
%
%   See also: ndi.v2.subjectTypes, ndi.vintage.elementSubjectIds,
%             ndi.entity.search, ndi.session/getsubjects.

arguments
    ndi_session_obj
end

docs = ndi_session_obj.database_search(ndi.query('', 'isa', 'subject'));
if isempty(docs)
    docs = {};
    return;
end
docs = docs(:)';

untyped = false;
for i = 1:numel(docs)
    if ~hasType(ndi.v2.props(docs{i}))
        untyped = true;
        break;
    end
end
if ~untyped
    return;
end

apparatus = ndi.vintage.elementSubjectIds(ndi_session_obj);
if isempty(apparatus)
    return;
end
ids = cellfun(@(d) char(d.id()), docs, 'UniformOutput', false);
docs = docs(~ismember(ids, apparatus));
end

% -----------------------------------------------------------------------------
function tf = hasType(p)
%HASTYPE Does the subject (or entity) document P carry a non-empty type?
t = ndi.v2.blockOf(p, 'subject', 'type', []);
if isstruct(t)
    tf = isfield(t, 'name') && ~isempty(t.name);
else
    tf = ~isempty(t);
end
end
