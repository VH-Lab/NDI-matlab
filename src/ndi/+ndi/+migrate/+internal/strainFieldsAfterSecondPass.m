function report = strainFieldsAfterSecondPass(docs, v1Bodies)
%STRAINFIELDSAFTERSECONDPASS Compare each v1 openMINDS Strain's fields with the strain entity the second pass rebuilt.
%
%   REPORT = ndi.migrate.internal.strainFieldsAfterSecondPass(DOCS, V1BODIES)
%   reads the migrated documents DOCS (did2.document objects or V_eta body
%   structs, as the second pass leaves them) and the session's v1 bodies
%   V1BODIES (structs or JSON text). For every v1 openMINDS Strain document
%   (class `openminds` or `openminds_subject`, openMINDS type Strain) it finds
%   the strain entity that carries it and compares, field by field, what the
%   v1 document says with what the v2 documents say. Report only: it changes
%   nothing.
%
%   THE DECISION. Decided by Jess Haley, 2026-11-19 [strain fields checked
%   after the second pass] (did-schema did_v2_go_forward_class_audit.md):
%   DID-matlab's Strain round-trip inverse lists a Strain's `openminds_<n>`
%   child edges and its `geneticStrainType`, `species`, `backgroundStrain` and
%   `description` as deferred to the second pass, "and NDI's end-to-end round
%   trip checks them after the second pass". This is that check. The v1 side
%   is read here from the v1 bodies, not from the reports of the passes that
%   built the v2 side.
%
%   WHICH STRAIN ENTITY. In order:
%     by id        a strain entity whose base.id is the v1 Strain's id
%                  (ndi.migrate.internal.strainAssembly keeps it);
%     instance_of  an `instance_of` relation whose base.id is the v1 Strain's
%                  id (ndi.migrate.internal.subjectStrainAssembly keeps the
%                  replaced assertion's id on it): its parent;
%     by name      the one strain entity with the v1 Strain's name in the
%                  Strain's session or in a dataset of the batch (an ancestor
%                  strain, whose own assertion was dropped: [lab-made strain
%                  ids are an accepted loss too], "a strain is identified by
%                  its name in its session").
%   A Strain with no such entity is `not_mapped_no_entity`; one whose name
%   names several is `not_mapped_ambiguous`. Neither is compared.
%
%   WHAT IS COMPARED, per mapped Strain:
%     name                 fields.name                -> entity.name
%     description          fields.description         -> entity.notes
%     species              fields.species             -> the term assertion
%                          about the strain whose variable is NCIT:C45293
%     genetic_strain_type  fields.geneticStrainType   -> the term assertion
%                          whose variable is EMPTY:0000347
%     background_strain    fields.backgroundStrain    -> the strain's
%                          `derived_from` relations, to the entity each parent
%                          Strain maps to (as a set; a parent that maps to no
%                          entity is counted `parent_not_mapped`)
%   A term is the same when its node is the same (CURIE rewrite of
%   etaShape.curie, compared case-insensitively), or, when v1 gives no node,
%   when its name is the same. A field the v1 document leaves empty is
%   `v1_absent` and must have no v2 value either.
%   The `openminds_<n>` CHILD EDGES are counted by what carries each target:
%   a field compared above (`to_compared_field`), another field of the
%   Strain, which ndi.migrate.internal.strainLeftovers writes
%   (`to_other_field`), or no field at all (`to_no_field`, a difference: no
%   pass reads such a target as part of the strain).
%
%   REPORT, denominators first:
%     v1_strains_inspected     v1 openMINDS Strain documents in V1BODIES
%     documents_inspected      migrated documents read
%     strain_entities_seen     strain entities among them
%     mapped_by_id, mapped_by_instance_of, mapped_by_name, not_mapped_no_entity,
%     not_mapped_ambiguous     the partition of v1_strains_inspected
%     state                    'measured' when at least one Strain was
%                              compared, else 'not measured'
%     name, description, species, genetic_strain_type, background_strain
%                              per field: compared (v1 has a value) = equal
%                              + differ; v1_absent, of which v2_only (v2 has
%                              a value v1 does not)
%     background_strain.parent_not_mapped
%     child_edges              total, to_compared_field, to_other_field,
%                              to_no_field
%     differences              the first DIFFERENCE_CAP (20) differences, in
%                              v1 order (the counts are exact)
%     unreadable_documents     documents that could not be read as a struct
%
%   See also ndi.migrate.internal.subjectStrainAssembly,
%            ndi.migrate.internal.strainAssembly, ndi.migrate.local.

arguments
    docs cell
    v1Bodies cell
end

DIFFERENCE_CAP = 20;
S = ndi.migrate.internal.etaShape;
fieldNames = {'name', 'description', 'species', 'genetic_strain_type', 'background_strain'};
report = struct( ...
    'v1_strains_inspected',  0, ...
    'documents_inspected',   0, ...
    'strain_entities_seen',  0, ...
    'mapped_by_id',          0, ...
    'mapped_by_instance_of', 0, ...
    'mapped_by_name',        0, ...
    'not_mapped_no_entity',  0, ...
    'not_mapped_ambiguous',  0, ...
    'state',                 'not measured');
for k = 1:numel(fieldNames)
    report.(fieldNames{k}) = struct('compared', 0, 'equal', 0, 'differ', 0, 'v1_absent', 0, 'v2_only', 0);
end
report.background_strain.parent_not_mapped = 0;
report.child_edges = struct('total', 0, 'to_compared_field', 0, ...
    'to_other_field', 0, 'to_no_field', 0);
report.differences = struct('v1_id', {}, 'field', {}, 'v1', {}, 'v2', {}, 'why', {});
report.unreadable_documents = 0;
nDifferences = 0;

% ---- the v1 side ----------------------------------------------------------
v1 = decodeAll(v1Bodies);
v1ById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(v1)
    id = baseId(v1{k});
    if ~isempty(id); v1ById(id) = k; end
end
strains = [];
for k = 1:numel(v1)
    if any(strcmp(className(v1{k}), {'openminds', 'openminds_subject'})) ...
            && isStrain(v1{k})
        strains(end+1) = k; %#ok<AGROW>
    end
end
report.v1_strains_inspected = numel(strains);

% ---- the v2 side ----------------------------------------------------------
out = cell(1, numel(docs));
nOut = 0;
for k = 1:numel(docs)
    d = docs{k};
    try
        if ~isstruct(d); d = d.toStruct(); end
    catch
        report.unreadable_documents = report.unreadable_documents + 1;
        continue;
    end
    nOut = nOut + 1;
    out{nOut} = d;
end
out = out(1:nOut);
report.documents_inspected = nOut;

entityById   = containers.Map('KeyType', 'char', 'ValueType', 'any');
instanceOfId = containers.Map('KeyType', 'char', 'ValueType', 'char');   % relation id -> parent
derivedFrom  = containers.Map('KeyType', 'char', 'ValueType', 'any');    % strain id -> parents
termsAbout   = containers.Map('KeyType', 'char', 'ValueType', 'any');    % strain id -> {variable, term}
datasetIds   = {};
strainIds    = {};
for k = 1:nOut
    s = out{k};
    if S.isEntity(s)
        t = S.entityType(s);
        if strcmp(t, 'strain')
            strainIds{end+1} = baseId(s); %#ok<AGROW>
            entityById(baseId(s)) = s;
        elseif strcmp(t, 'dataset')
            datasetIds{end+1} = baseId(s); %#ok<AGROW>
        end
        continue;
    end
    rn = S.relationName(s);
    if strcmp(rn, 'instance_of')
        [~, parent] = S.relationEnds(s);
        if ~isempty(parent); instanceOfId(baseId(s)) = parent; end
        continue;
    elseif strcmp(rn, 'derived_from')
        [child, parent] = S.relationEnds(s);
        if ~isempty(child) && ~isempty(parent)
            if isKey(derivedFrom, child)
                derivedFrom(child) = [derivedFrom(child), {parent}];
            else
                derivedFrom(child) = {parent};
            end
        end
        continue;
    end
    if S.isStatement(s, 'assertion', 'term')
        about = S.aboutId(s);
        if isempty(about); continue; end
        row = {S.variable(s), S.termValue(s)};
        if isKey(termsAbout, about)
            termsAbout(about) = [termsAbout(about); row];
        else
            termsAbout(about) = row;
        end
    end
end
report.strain_entities_seen = numel(strainIds);
strainSession = cellfun(@(i) char(ndi.v2.sessionIdOf(entityById(i))), strainIds, ...
    'UniformOutput', false);
strainName = cellfun(@(i) entityName(entityById(i)), strainIds, 'UniformOutput', false);

% ---- map every v1 Strain to its entity ------------------------------------
mapped = containers.Map('KeyType', 'char', 'ValueType', 'char');   % v1 id -> entity id
for k = strains
    b = v1{k};
    id = baseId(b);
    if isKey(entityById, id)
        mapped(id) = id;
        report.mapped_by_id = report.mapped_by_id + 1;
        continue;
    end
    if isKey(instanceOfId, id) && isKey(entityById, instanceOfId(id))
        mapped(id) = instanceOfId(id);
        report.mapped_by_instance_of = report.mapped_by_instance_of + 1;
        continue;
    end
    nm = textField(fieldsOf(b), {'name'});
    scope = [{char(ndi.v2.sessionIdOf(b))}, datasetIds];
    hit = find(strcmp(strainName, nm) & ismember(strainSession, scope));
    if isempty(nm) || isempty(hit)
        report.not_mapped_no_entity = report.not_mapped_no_entity + 1;
        addDifference(id, 'strain entity', nm, '', ...
            'no strain entity carries this Strain (by id, instance_of or name in its session)');
    elseif numel(hit) > 1
        report.not_mapped_ambiguous = report.not_mapped_ambiguous + 1;
        addDifference(id, 'strain entity', nm, strjoin(strainIds(hit), ', '), ...
            sprintf('%d strain entities carry this name in its session', numel(hit)));
    else
        mapped(id) = strainIds{hit};
        report.mapped_by_name = report.mapped_by_name + 1;
    end
end

% ---- compare --------------------------------------------------------------
for k = strains
    b = v1{k};
    id = baseId(b);
    if ~isKey(mapped, id); continue; end
    eid = mapped(id);
    e = entityById(eid);
    f = fieldsOf(b);

    compareText('name', textField(f, {'name'}), entityName(e));
    notes = '';
    if isfield(e.entity, 'notes'); notes = strtrim(charOf(e.entity.notes)); end
    compareText('description', textField(f, {'description'}), notes);

    rows = {};
    if isKey(termsAbout, eid); rows = termsAbout(eid); end
    compareTerm('species', v1Term(getAny(f, {'species'})), ...
        termsWithVariable(rows, 'NCIT:C45293', {'Species', 'species'}));
    compareTerm('genetic_strain_type', ...
        v1Term(getAny(f, {'geneticStrainType', 'genetic_strain_type'})), ...
        termsWithVariable(rows, 'EMPTY:0000347', {'genetic strain type'}));

    % background strain: the parents' entities, as a set
    parents = ndiRefs(getAny(f, {'backgroundStrain', 'background_strain'}));
    want = {};
    for p = 1:numel(parents)
        if isKey(mapped, parents{p})
            want{end+1} = mapped(parents{p}); %#ok<AGROW>
        else
            report.background_strain.parent_not_mapped = ...
                report.background_strain.parent_not_mapped + 1;
        end
    end
    have = {};
    if isKey(derivedFrom, eid); have = derivedFrom(eid); end
    c = report.background_strain;
    if isempty(parents)
        c.v1_absent = c.v1_absent + 1;
        if ~isempty(have)
            c.v2_only = c.v2_only + 1;
            addDifference(id, 'background_strain', '', strjoin(unique(have), ', '), ...
                'v1 names no background strain; the strain entity is derived_from one');
        end
    elseif numel(want) == numel(parents)
        c.compared = c.compared + 1;
        if isequal(sort(unique(want)), sort(unique(have)))
            c.equal = c.equal + 1;
        else
            c.differ = c.differ + 1;
            addDifference(id, 'background_strain', strjoin(unique(want), ', '), ...
                strjoin(unique(have), ', '), ...
                'the derived_from parents are not the entities of the v1 background strains');
        end
    end
    report.background_strain = c;

    % the openminds_<n> child edges: what carries each target
    roleRefs = [ndiRefs(getAny(f, {'species'})), ...
        ndiRefs(getAny(f, {'geneticStrainType', 'genetic_strain_type'})), parents];
    otherRefs = {};
    fn = fieldnames(f);
    for q = 1:numel(fn)
        otherRefs = [otherRefs, ndiRefs(f.(fn{q}))]; %#ok<AGROW>
    end
    for t = childEdgeTargets(b)
        report.child_edges.total = report.child_edges.total + 1;
        if any(strcmp(roleRefs, t{1}))
            report.child_edges.to_compared_field = report.child_edges.to_compared_field + 1;
        elseif any(strcmp(otherRefs, t{1}))
            report.child_edges.to_other_field = report.child_edges.to_other_field + 1;
        else
            report.child_edges.to_no_field = report.child_edges.to_no_field + 1;
            addDifference(id, 'openminds child edge', t{1}, '', ...
                'the edge''s target is named by no field of the Strain');
        end
    end
end
if any(cellfun(@(n) report.(n).compared, fieldNames) > 0)
    report.state = 'measured';
end

    % ------------------------------------------------------------------
    function compareText(field, a, b)
        cc = report.(field);
        if isempty(a)
            cc.v1_absent = cc.v1_absent + 1;
            if ~isempty(b)
                cc.v2_only = cc.v2_only + 1;
                addDifference(id, field, '', b, 'v1 has no value; v2 has one');
            end
        else
            cc.compared = cc.compared + 1;
            if strcmp(a, b)
                cc.equal = cc.equal + 1;
            else
                cc.differ = cc.differ + 1;
                addDifference(id, field, a, b, 'the values differ');
            end
        end
        report.(field) = cc;
    end

    function compareTerm(field, want, have)
        cc = report.(field);
        if isempty(want.node) && isempty(want.name)
            cc.v1_absent = cc.v1_absent + 1;
            if ~isempty(have)
                cc.v2_only = cc.v2_only + 1;
                addDifference(id, field, '', termText(have{1}), ...
                    'v1 has no value; the strain entity has an assertion');
            end
        else
            cc.compared = cc.compared + 1;
            if numel(have) == 1 && sameTerm(want, have{1})
                cc.equal = cc.equal + 1;
            else
                cc.differ = cc.differ + 1;
                got = strjoin(cellfun(@termText, have, 'UniformOutput', false), '; ');
                addDifference(id, field, termText(want), got, sprintf( ...
                    '%d assertion(s) about the strain entity, not one with the v1 term', ...
                    numel(have)));
            end
        end
        report.(field) = cc;
    end

    function t = v1Term(v)
        % the v1 term: an inline name, or the name and node of the `ndi://`
        % child document
        t = struct('node', '', 'name', '');
        if isempty(v); return; end
        refs = ndiRefs(v);
        if isempty(refs)
            t.name = firstText(v);
            return;
        end
        for r = 1:numel(refs)
            if ~isKey(v1ById, refs{r}); continue; end
            ff = fieldsOf(v1{v1ById(refs{r})});
            t.name = textField(ff, {'name'});
            t.node = textField(ff, {'preferredOntologyIdentifier', ...
                'preferred_ontology_identifier', 'ontologyIdentifier', 'ontology_identifier'});
            return;
        end
        t.name = ['ndi://' refs{1}];   % the child is not in the batch
    end

    function addDifference(v1id, field, a, b, why)
        nDifferences = nDifferences + 1;
        if nDifferences <= DIFFERENCE_CAP
            report.differences(end+1) = struct('v1_id', v1id, 'field', field, ...
                'v1', a, 'v2', b, 'why', why);
        end
    end
end

% ===================== helpers ==============================================

function out = decodeAll(raw)
out = {};
for k = 1:numel(raw)
    b = raw{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if isstruct(b) && isscalar(b)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function id = baseId(s)
id = '';
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, 'id')
    id = charOf(s.base.id);
end
end

function c = className(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = charOf(s.document_class.class_name);
end
end

function b = omBlock(s)
b = struct();
if isfield(s, 'openminds') && isstruct(s.openminds)
    b = s.openminds;
elseif isfield(s, 'openminds_subject') && isstruct(s.openminds_subject)
    b = s.openminds_subject;
end
end

function tf = isStrain(s)
% by matlab_type's last segment or openminds_type's last segment
b = omBlock(s);
tf = false;
for nm = {'matlab_type', 'openminds_type'}
    if isfield(b, nm{1})
        v = charOf(b.(nm{1}));
        parts = regexp(v, '[./]', 'split');
        if ~isempty(parts) && strcmpi(strtrim(parts{end}), 'Strain')
            tf = true;
            return;
        end
    end
end
end

function f = fieldsOf(s)
f = struct();
b = omBlock(s);
if isfield(b, 'fields') && isstruct(b.fields) && isscalar(b.fields)
    f = b.fields;
end
end

function v = getAny(s, names)
v = [];
for k = 1:numel(names)
    if isfield(s, names{k})
        v = s.(names{k});
        return;
    end
end
end

function t = textField(s, names)
t = firstText(getAny(s, names));
end

function t = firstText(v)
t = '';
if iscell(v)
    if isempty(v); return; end
    v = v{1};
end
if isstring(v)
    if isempty(v); return; end
    v = v(1);
end
if ischar(v) || isstring(v)
    t = strtrim(char(v));
end
end

function s = charOf(v)
s = firstText(v);
end

function n = entityName(e)
n = '';
if isfield(e, 'entity') && isfield(e.entity, 'name')
    n = strtrim(charOf(e.entity.name));
end
end

function ids = ndiRefs(v)
ids = {};
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ischar(e) && startsWith(e, 'ndi://') && numel(e) > 6
        ids{end+1} = e(7:end); %#ok<AGROW>
    end
end
end

function ids = childEdgeTargets(s)
% the targets of the `openminds_<n>` dependencies (the one empty `openminds`
% dependency a leaf carries has no target)
ids = {};
if ~isfield(s, 'depends_on') || ~isstruct(s.depends_on); return; end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if ~isfield(d, 'name') || isempty(regexp(charOf(d.name), '^openminds(_\d+)?$', 'once'))
        continue;
    end
    v = '';
    if isfield(d, 'value'); v = charOf(d.value); end
    if ~isempty(v); ids{end+1} = v; end %#ok<AGROW>
end
end

function out = termsWithVariable(rows, node, names)
out = {};
for r = 1:size(rows, 1)
    v = rows{r, 1};
    vn = strtrim(char(v.node));
    if (~isempty(vn) && strcmpi(vn, node)) || (isempty(vn) && any(strcmpi(strtrim(char(v.name)), names)))
        out{end+1} = rows{r, 2}; %#ok<AGROW>
    end
end
end

function tf = sameTerm(want, have)
wn = ndi.migrate.internal.etaShape.curie(want.node);
hn = ndi.migrate.internal.etaShape.curie(char(have.node));
if ~isempty(wn)
    tf = strcmpi(wn, hn);
else
    tf = strcmp(strtrim(want.name), strtrim(char(have.name)));
end
end

function t = termText(x)
t = sprintf('%s "%s"', char(x.node), char(x.name));
end
