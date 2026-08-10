function [kept, minted, report] = strainAssembly(structs)
%STRAINASSEMBLY V_eta second pass: assemble the UNATTACHED `openminds`
%   documents that carry openMINDS Strain objects into `strain` ENTITIES, with
%   their ids preserved, consuming their Species / GeneticStrainType FRAGMENT
%   documents into the strain's `species` and `genetic_strain_type` fields and
%   wiring `backgroundStrain` into the recursive `background_strain_#` edge.
%
%   SIGNED MODEL (DID-schema `V_eta_openminds_family_record.md` Part 7,
%   TEAM-SIGN-OFF jess 2026-08-08): "the 3 unattached Strain documents become
%   `strain` entities with their ids preserved and OP50-GFP's pedigree as
%   `background_strain_1`; the other 5 documents are Species/GeneticStrainType
%   fragments and are consumed into their parent strain's `species` and
%   `genetic_strain_type` fields; no `term_assertion` is emitted, because there
%   is no subject; the build is a second-pass assembler, and the `strain_id`
%   edge is attached by the same pass that mints subjects from
%   `ontologyTableRow`."
%
%   STRUCTS is a cell of V_eta document body structs (the pass-1 output; the
%   bare `openminds` class has no migrator and passes through). Returns KEPT
%   (the surviving bodies, with the consumed Strain and fragment documents
%   removed), MINTED (the new `strain` bodies, tagged schema_version 'V_eta'),
%   and REPORT (denominator first; REPORT.changed gates the caller's rebuild).
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A SECOND PASS AND NOT A `+migrators_j` FILE
%   ---------------------------------------------------------------------
%   The `species` and `genetic_strain_type` VALUES live in OTHER documents. A
%   Strain's child objects each become their own document and the parent's
%   field is replaced by an `ndi://<childId>` string:
%
%     git show origin/main:src/ndi/+ndi/+database/+fun/openMINDSobj2struct.m
%         s = ndi.database.fun.openMINDSobj2struct({f_here},cachekey);
%         child_index = find(strcmp(char(f_here.id),{s.openminds_id}));
%         fields_here{k} = ['ndi://' s(child_index).ndi_id];
%
%     git show origin/main:src/ndi/+ndi/+database/+fun/openMINDSobj2ndi_document.m
%         if startsWith(g{k},'ndi://')
%             id_here = g{k}(7:end);
%             d{i} = add_dependency_value_n(d{i},'openminds',id_here,'ErrorIfNotFound',0);
%
%   So the pedigree and the vocabulary values are reachable only across
%   documents, which a single-document migrator cannot follow.
%
%   THE `fields` KEYS STAY camelCase. did2.convert.universalRenames snake-cases
%   only ONE level -- `snakeCaseBlockFields` walks `fieldnames(block)` for each
%   top-level property block and stops (universalRenames.m:351-367). `fields`
%   is a nested struct inside the `openminds` block, so `geneticStrainType`,
%   `backgroundStrain`, `ontologyIdentifier`, `preferredOntologyIdentifier`
%   arrive unchanged. Every read below still takes a snake_case fallback, per
%   the standing migrator lesson.
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM THE WRITER
%   ---------------------------------------------------------------------
%     git show origin/main:src/ndi/+ndi/+setup/+conv/+haley/doImport.m
%       :70-89    species = openminds.controlledterms.Species
%                 species.name='Escherichia coli'; .preferredOntologyIdentifier='NCBITaxon:562'
%                 OP50 = openminds.core.research.Strain
%                 OP50.name='Escherichia coli OP50'; .species=species
%                 OP50.ontologyIdentifier='NCBITaxon:637912'; .geneticStrainType='wild type'
%                 strainDoc = openMINDSobj2ndi_document(OP50, session.id);
%       :696-706  OP50GFP.name='OP50-GFP'; .species=species
%                 .ontologyIdentifier='WBStrain:00041972'; .geneticStrainType='transgenic'
%                 .backgroundStrain=OP50
%
%   `geneticStrainType` is ASSIGNED A CHAR. Whether openMINDS_MATLAB coerces it
%   into a `controlledterms.GeneticStrainType` instance (and so into its own
%   document) was NOT read -- the library is not in scope; Part 7 infers it from
%   the 3/5 document split and from the attached histogram where
%   GeneticStrainType (2,365) equals Strain (2,365) exactly. BOTH SHAPES ARE
%   THEREFORE HANDLED: an inline char becomes `{node:'', name:<char>}`, an
%   `ndi://` reference is resolved from its fragment document.
%
%   ---------------------------------------------------------------------
%   RULES OBSERVED
%   ---------------------------------------------------------------------
%   * IDS PRESERVED. The strain documents are referenced BY ID from ordinary
%     table cells -- `dataTable{:,'bacteriaStrain'} = {strainDoc{1}.id}`
%     (haley/doImport.m:164 and :734) -- not through `depends_on`, so nothing
%     would flag a re-mint. The minted `strain` reuses the openminds document's
%     `base.id` exactly.
%   * NOTHING IS EMITTED HOLLOW. `strain` declares `name`, `species` and
%     `genetic_strain_type` as mustBeNonEmpty (schemas/V_eta/stable/strain.json).
%     A Strain missing any of the three is LEFT AS PASSTHROUGH and counted
%     (REPORT.strains_incomplete), never emitted with a vacuous required field.
%   * NO EMPTY EDGE. A `backgroundStrain` reference that does not resolve to a
%     Strain document in this set produces NO `background_strain_#` entry; it is
%     counted (REPORT.background_unresolved).
%   * A FRAGMENT IS CONSUMED ONLY IF EVERY DOCUMENT THAT REFERENCES IT IS A
%     STRAIN THIS PASS ASSEMBLED. Otherwise it stays, so a surviving
%     passthrough's `openminds_#` edge cannot dangle.
%   * NO `term_assertion` IS EMITTED. These documents carry no `subject_id` --
%     they are not assertions about anybody. That is the whole reason
%     `strain` is an entity.
%
%   ---------------------------------------------------------------------
%   DEFERRED, ON PURPOSE
%   ---------------------------------------------------------------------
%   The `strain_id` edge on `term_assertion` is NOT attached here. Part 7 puts
%   it with the pass that mints subjects from `ontologyTableRow` (#53), because
%   that is where the row's `bacteriaStrain` cell -- holding this strain's id --
%   becomes a subject. That pass does not exist yet
%   (did2.convert.migrators_j.ontology_table_row still carries `subject_id`
%   forward from the source document). Nothing here blocks it: the id it will
%   point at is preserved.
%
%   Group B of Part 7 (the metadata-app dataset graph: Dataset / Person /
%   Organization / funding) is NOT handled here. It maps to the six classes
%   `metadata_editor` already emits, contributed ZERO documents to the three
%   corpora measured, and its open question (#73 -- whether a `metadata_editor`
%   document is always written alongside the openMINDS graph) is unanswered.
%   Bare `openminds` documents that are not Strain/Species/GeneticStrainType
%   are left untouched and counted (REPORT.openminds_other).
%
%   See also: ndi.migrate.local, ndi.migrate.internal.pathSPromotion,
%     ndi.migrate.internal.ensembleMembership,
%     DID-schema schemas/V_eta_openminds_family_record.md Part 7.

arguments
    structs cell
end

kept   = structs;
minted = {};

report = struct();
report.documents_inspected    = numel(structs);
report.openminds_seen         = 0;
report.openminds_other        = 0;   % bare openminds that is not a strain/fragment
report.strains_seen           = 0;
report.strains_assembled      = 0;
report.strains_incomplete     = 0;   % missing a mustBeNonEmpty field -> passthrough
report.incomplete_reasons     = {};
report.fragments_seen         = 0;
report.fragments_consumed     = 0;
report.fragments_retained     = 0;
report.background_edges       = 0;
report.background_unresolved  = 0;
report.background_over_max    = 0;   % > 2 parents; strain.json declares max_count 2
report.changed                = false;

if isempty(structs)
    return;
end

n = numel(structs);
isOpenminds = false(1, n);
isStrainDoc = false(1, n);
idOf        = cell(1, n);
byId        = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:n
    idOf{i} = baseField(structs{i}, 'id', '');
    if ~strcmp(classNameOf(structs{i}), 'openminds')
        continue;
    end
    isOpenminds(i) = true;
    report.openminds_seen = report.openminds_seen + 1;
    isStrainDoc(i) = isOpenmindsType(structs{i}, 'Strain');
    if ~isempty(idOf{i})
        byId(idOf{i}) = i;
    end
end

% Census FIRST, unconditionally -- an instrument reports its denominator even
% when it has no work to do. (An early return before this point is how a
% counter comes to print zeros while reading nothing.)
for i = find(isOpenminds)
    if isStrainDoc(i)
        report.strains_seen = report.strains_seen + 1;
    elseif isOpenmindsType(structs{i}, 'Species') ...
            || isOpenmindsType(structs{i}, 'GeneticStrainType')
        report.fragments_seen = report.fragments_seen + 1;
    else
        report.openminds_other = report.openminds_other + 1;
    end
end

if ~any(isStrainDoc)
    return;
end

% --- pass 1: which Strain documents can be assembled at all? ----------------
% background_strain_# must point at a strain document that SURVIVES, so the
% completeness decision has to be made for every strain before any edge is
% written.
strainIdx      = find(isStrainDoc);
assembled      = false(1, n);
speciesTermOf  = cell(1, n);
gstTermOf      = cell(1, n);
usedFragments  = containers.Map('KeyType', 'char', 'ValueType', 'any');

for k = 1:numel(strainIdx)
    i = strainIdx(k);
    s = structs{i};
    f = openmindsFields(s);

    nm = charField(f, {'name'});
    [speciesTerm, speciesFrag] = resolveTerm(f, {'species'}, byId, structs);
    [gstTerm, gstFrag] = resolveTerm(f, ...
        {'geneticStrainType', 'genetic_strain_type'}, byId, structs);

    why = '';
    if isempty(nm)
        why = 'name';
    elseif ~termIsPopulated(speciesTerm)
        why = 'species';
    elseif ~termIsPopulated(gstTerm)
        why = 'genetic_strain_type';
    end
    if ~isempty(why)
        report.strains_incomplete = report.strains_incomplete + 1;
        report.incomplete_reasons{end+1} = ...
            sprintf('%s: missing %s', shortId(idOf{i}), why); %#ok<AGROW>
        continue;
    end

    assembled(i)     = true;
    speciesTermOf{i} = speciesTerm;
    gstTermOf{i}     = gstTerm;
    frags = [reshape(speciesFrag, 1, []), reshape(gstFrag, 1, [])];
    for fr = 1:numel(frags)
        addUse(usedFragments, frags{fr}, idOf{i});
    end
end

if ~any(assembled)
    return;
end

% --- pass 2: mint the strain entities --------------------------------------
for k = 1:numel(strainIdx)
    i = strainIdx(k);
    if ~assembled(i)
        continue;
    end
    s = structs{i};
    f = openmindsFields(s);

    body = struct();
    body.document_class = struct('class_name', 'strain', ...
        'class_version', '1.0.0', ...
        'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
        'schema_version', 'V_eta');

    % background_strain_#: only to strains that survive this pass.
    deps = struct('name', {}, 'value', {});
    parents = ndiRefs(getAny(f, {'backgroundStrain', 'background_strain'}));
    nEdge = 0;
    for p = 1:numel(parents)
        pid = parents{p};
        if isKey(byId, pid) && assembled(byId(pid))
            nEdge = nEdge + 1;
            deps(end+1) = struct('name', sprintf('background_strain_%d', nEdge), ...
                'value', pid); %#ok<AGROW>
            report.background_edges = report.background_edges + 1;
        else
            report.background_unresolved = report.background_unresolved + 1;
        end
    end
    if nEdge > 2
        % strain.json declares max_count 2. Emitted as found rather than
        % silently truncated -- a real violation is a finding, not something to
        % hide. It will show up in validation.
        report.background_over_max = report.background_over_max + 1;
    end
    body.depends_on = deps;

    % base.id PRESERVED -- ontologyTableRow's `bacteriaStrain` cell holds it.
    body.base = struct('id', idOf{i}, ...
        'session_id', baseField(s, 'session_id', ''), ...
        'name', 'migrated_strain', ...
        'datestamp', baseField(s, 'datestamp', '2024-01-01T00:00:00.000Z'));

    % entity: cross-reference identifiers. Strain.ontologyIdentifier is a CURIE
    % in one of several regimes (NCBITaxon:, RRID:, WBStrain:, EMPTY:, or absent
    % -- record Part 2), so scheme/value is split on the first colon and the
    % array is simply empty when the writer gives none.
    % (assigned field-by-field, not via struct(): a struct-array value inside
    % struct() is a well-known way to get a struct ARRAY back by accident.)
    body.entity = struct();
    body.entity.global_identifier = ...
        identifiers(getAny(f, {'ontologyIdentifier', 'ontology_identifier'}));

    blk = struct();
    blk.name                = charField(f, {'name'});
    blk.species             = speciesTermOf{i};
    blk.genetic_strain_type = gstTermOf{i};
    desc = charField(f, {'description'});
    if ~isempty(desc); blk.description = desc; end
    phen = charField(f, {'phenotype'});
    if ~isempty(phen); blk.phenotype = phen; end
    lab = charField(f, {'laboratoryCode', 'laboratory_code'});
    if ~isempty(lab); blk.laboratory_code = lab; end
    syn = cellstrField(f, {'synonym'});
    if ~isempty(syn); blk.synonym = syn; end
    body.strain = blk;

    minted{end+1} = body; %#ok<AGROW>
    report.strains_assembled = report.strains_assembled + 1;
end

% --- pass 3: consume the sources -------------------------------------------
% A fragment goes only when EVERY document that references it is a strain this
% pass assembled; otherwise a surviving passthrough's `openminds_#` edge would
% dangle. References are counted over the WHOLE set, through `depends_on` AND
% through the `ndi://` strings in `openminds.fields` -- the id can travel either
% way, and only the `fields` route says which role it fills.
referrers = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:n
    src = idOf{i};
    targets = referencedIds(structs{i});
    for t = 1:numel(targets)
        addUse(referrers, targets{t}, src);
    end
end

removeMask = false(1, n);
removeMask(assembled) = true;    % replaced 1:1 by the minted strain (same id)

consumedStrains = idOf(assembled);
for i = find(isOpenminds)
    if isStrainDoc(i) || isempty(idOf{i})
        continue;
    end
    if ~(isOpenmindsType(structs{i}, 'Species') ...
            || isOpenmindsType(structs{i}, 'GeneticStrainType'))
        continue;   % not a fragment of this family; leave it alone
    end
    if ~isKey(usedFragments, idOf{i})
        report.fragments_retained = report.fragments_retained + 1;
        continue;   % referenced by no assembled strain
    end
    who = {};
    if isKey(referrers, idOf{i}); who = referrers(idOf{i}); end
    if all(ismember(who, consumedStrains))
        removeMask(i) = true;
        report.fragments_consumed = report.fragments_consumed + 1;
    else
        report.fragments_retained = report.fragments_retained + 1;
    end
end

kept = structs(~removeMask);
report.changed = true;
end

% ===================== openMINDS accessors =============================

function tf = isOpenmindsType(s, typeName)
%ISOPENMINDSTYPE Match on matlab_type's trailing class OR openminds_type's
%   trailing IRI segment, so the check survives an openMINDS namespace change
%   (openminds.ebrains.eu -> openminds.om-i.org) and either writer spelling.
tf = false;
if ~isfield(s, 'openminds') || ~isstruct(s.openminds)
    return;
end
b = s.openminds;
mt = ''; ot = '';
if isfield(b, 'matlab_type');    mt = char(b.matlab_type);    end
if isfield(b, 'openminds_type'); ot = char(b.openminds_type); end
tf = endsWithSegment(mt, '.', typeName) || endsWithSegment(ot, '/', typeName);
end

function tf = endsWithSegment(str, sep, seg)
tf = false;
if isempty(str); return; end
parts = strsplit(str, sep);
tf = strcmpi(strtrim(parts{end}), seg);
end

function f = openmindsFields(s)
f = struct();
if isfield(s, 'openminds') && isstruct(s.openminds) ...
        && isfield(s.openminds, 'fields') && isstruct(s.openminds.fields)
    f = s.openminds.fields;
end
end

function [term, frags] = resolveTerm(f, names, byId, structs)
%RESOLVETERM An ontology_term for a Strain field that is either an inline char
%   or an `ndi://` reference to a controlled-term FRAGMENT document.
term  = struct('node', '', 'name', '');
frags = {};
v = getAny(f, names);
if isempty(v)
    return;
end
refs = ndiRefs(v);
if isempty(refs)
    % inline char (the `geneticStrainType = 'wild type'` shape). No CURIE is
    % available, so the node stays empty -- normalising 'wild type' vs
    % 'wildtype' is the T8 binding job, not this pass's.
    term.name = firstChar(v);
    return;
end
for r = 1:numel(refs)
    if ~isKey(byId, refs{r}); continue; end
    fr = structs{byId(refs{r})};
    ff = openmindsFields(fr);
    nm = charField(ff, {'name'});
    nd = charField(ff, {'preferredOntologyIdentifier', ...
        'preferred_ontology_identifier', 'ontologyIdentifier', ...
        'ontology_identifier'});
    if isempty(nm) && isempty(nd); continue; end
    term.name = nm;
    term.node = nd;
    frags{end+1} = refs{r}; %#ok<AGROW>
    return;      % the fields are single-valued in every writer we have
end
end

function ids = ndiRefs(v)
%NDIREFS The `ndi://<id>` document ids inside a fields value (char, cellstr or
%   string), in order.
ids = {};
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ~ischar(e); continue; end
    if startsWith(e, 'ndi://') && numel(e) > 6
        ids{end+1} = e(7:end); %#ok<AGROW>
    end
end
end

function gid = identifiers(v)
%IDENTIFIERS entity.global_identifier -- an ARRAY of {scheme, value}, split on
%   the first colon of the CURIE. Empty when the writer gives none (115 strains
%   carry no identifier at all; record Part 2).
gid = struct('scheme', {}, 'value', {});
raw = firstChar(v);
if isempty(raw); return; end
c = strfind(raw, ':');
if isempty(c)
    gid(1) = struct('scheme', '', 'value', strtrim(raw));
else
    gid(1) = struct('scheme', strtrim(raw(1:c(1)-1)), ...
        'value', strtrim(raw(c(1)+1:end)));
end
end

% ===================== struct accessors ================================

function tf = termIsPopulated(t)
tf = isstruct(t) && ((isfield(t, 'node') && ~isempty(strtrim(char(t.node)))) ...
    || (isfield(t, 'name') && ~isempty(strtrim(char(t.name)))));
end

function v = getAny(s, names)
v = [];
if ~isstruct(s); return; end
for k = 1:numel(names)
    if isfield(s, names{k}) && ~isempty(s.(names{k}))
        v = s.(names{k});
        return;
    end
end
end

function c = charField(s, names)
c = firstChar(getAny(s, names));
end

function c = firstChar(v)
c = '';
if isempty(v); return; end
if isstring(v); v = cellstr(v); end
if iscell(v)
    if isempty(v); return; end
    v = v{1};
    if isstring(v); v = char(v); end
end
if ischar(v); c = strtrim(v); end
end

function out = cellstrField(s, names)
out = {};
v = getAny(s, names);
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ischar(e) && ~isempty(strtrim(e)); out{end+1} = strtrim(e); end %#ok<AGROW>
end
end

function out = referencedIds(s)
%REFERENCEDIDS Every document id this body points at -- `depends_on` values and
%   `ndi://` strings inside `openminds.fields`.
out = {};
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        d = s.depends_on(k);
        v = '';
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        end
        if ~isempty(v); out{end+1} = v; end %#ok<AGROW>
    end
end
f = openmindsFields(s);
fn = fieldnames(f);
for k = 1:numel(fn)
    r = ndiRefs(f.(fn{k}));
    for j = 1:numel(r); out{end+1} = r{j}; end %#ok<AGROW>
end
% `unique` on a cellstr returns a COLUMN; reshape to a row so the caller's
% index loop and any `for x = out` see N entries rather than one.
out = reshape(unique(out), 1, []);
end

function addUse(map, key, user)
if isempty(key); return; end
if isKey(map, key)
    cur = map(key);
else
    cur = {};
end
if ~any(strcmp(cur, user))
    cur{end+1} = user;
end
map(key) = cur; %#ok<NASGU>
end

function c = classNameOf(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) ...
        && ~isempty(s.base.(name))
    v = s.base.(name);
end
end

function s = shortId(idStr)
s = char(idStr);
if numel(s) > 8; s = s(1:8); end
end
