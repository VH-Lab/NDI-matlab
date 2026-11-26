function parts = regionPartBodies(parentId, siteTerm, sideTerm, source, ids)
%REGIONPARTBODIES The documents of one region part, in the shape NDI's second
%   pass writes.
%
%   PARTS = ndi.migrate.internal.regionPartBodies(PARENTID, SITETERM, ...
%       SIDETERM, SOURCE, IDS)
%
%   Builds the part entity, its anatomical-kind term assertion, its
%   laterality term assertion (when SIDETERM is given), and the part_of
%   relation. The part is an `entity` of type `tissue` ("part of an organism:
%   a slice, a biopsy, a region", binding_registry_meta.json
%   entity_type_bindings), identity only; the anatomical term is its kind (an
%   assertion, D9), not a field, and is written as the source wrote it (never
%   mapped). PARENTID is the subject, or the slice the statement was about.
%   SOURCE (the statement or part that called for it) supplies the session
%   and datestamp. IDS is did2.convert.regionPartIds(PARENTID, SITETERM,
%   SIDETERM) (the part's computed ids and local identifier), or [] for a
%   region with no key, whose ids are minted in the caller's context.
%
%   PARTS is a struct {entity, assertion, relation, laterality} of document
%   body structs; `laterality` is [] with no side.
%
%   Moved out of ndi.migrate.internal.pathSPromotion (its local `mintPart`,
%   unchanged) so the Dabrowska map (ndi.setup.conv.dabrowska.sliceTetanus)
%   builds a slice's region part exactly as 'located' would: Decided by Jess
%   Haley, 2026-11-26 [Dab map re-parents region parts under slices]
%   (did-schema docs/plans/did_v2_go_forward_class_audit.md).
%
%   See also: ndi.migrate.internal.pathSPromotion, did2.convert.regionPartIds.

S = ndi.migrate.internal.etaShape;
sessionId = ndi.v2.sessionIdOf(source);
ds = baseField(source, 'creation_timestamp', '');
if isempty(ds)
    ds = baseField(source, 'datestamp', '');
end
common = {'SessionId', sessionId, 'Datestamp', ds};
partName = safeName(siteTerm);
if ~isempty(sideTerm)
    partName = [partName '_' safeName(sideTerm)];
end
if isempty(ids)
    ids = struct('part', did2.convert.mintId('tissue part'), 'kind', '', ...
        'laterality', '', 'relation', '', 'local_identifier', '');
end
partId = ids.part;

% local_identifier is REQUIRED on a tissue entity. Compose parent+part; trim
% any degenerate leading/trailing underscores (an empty parentId would leave
% one), and fall back to the document id if somehow empty -- the same
% guarantee the DID-side jEnsureLocalId gives. regionPartIds composes it the
% same way.
lid = ids.local_identifier;
if isempty(lid)
    lid = regexprep([shortId(parentId) '_' partName], '^_+|_+$', '');
end
if isempty(lid); lid = partId; end
ent = S.entity('tissue', struct('local_identifier', lid), 'Id', partId, common{:});

assertion = S.statement('assertion', 'term', partId, ...
    S.anatomicalStructureVariable(), siteTerm, 'Id', ids.kind, common{:});

laterality = [];
if ~isempty(sideTerm)
    laterality = S.statement('assertion', 'term', partId, ...
        lateralityVariable(), S.asTerm(sideTerm), 'Id', ids.laterality, common{:});
end

relation = S.relation(partId, parentId, ndi.v2.vocabTerm('relation', 'part_of'), ...
    'Id', ids.relation, common{:});

parts = struct('entity', ent, 'assertion', assertion, 'relation', relation);
parts.laterality = laterality;
end

function v = lateralityVariable()
% NCIT's `Laterality`, the variable pathSPromotion's LATERALITY_VARIABLE names
% ([laterality variable], Jess Haley, 2026-10-21)
v = struct('node', 'NCIT:C25185', 'name', 'Laterality');
end

function v = baseField(s, name, default)
v = default;
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) ...
        && ~isempty(s.base.(name))
    v = s.base.(name);
end
end

function nm = safeName(t)
raw = '';
if isfield(t, 'name') && ~isempty(t.name); raw = char(t.name);
elseif isfield(t, 'node'); raw = char(t.node); end
if isempty(raw); raw = 'part'; end
nm = lower(regexprep(raw, '[^A-Za-z0-9]+', '_'));
nm = regexprep(nm, '^_+|_+$', '');
if isempty(nm); nm = 'part'; end
end

function s = shortId(idStr)
s = char(idStr);
if numel(s) > 8; s = s(1:8); end
end
