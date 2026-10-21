function result = datasetMetadata(spec, sessionId, options)
%DATASETMETADATA Build the dataset-level V2 documents described by a spec.
%
%   RESULT = ndi.setup.V2.datasetMetadata(SPEC, SESSIONID) turns the dataset
%   metadata section of an import spec into V2 (V_eta) documents, built and
%   validated with did2.build. SPEC is a struct (jsondecode of the spec file)
%   or the path to a JSON spec file. SESSIONID is the session the documents
%   belong to: for dataset-level entities, the dataset's own session.
%
%   The spec lists entries by kind -- organizations, people, funding,
%   publications, web_resources, software, products, strains, chemicals,
%   formulations, instruments,
%   studies and one dataset -- each with a local `key`. References between
%   entries use keys (a person's `affiliations`, a funding's `funder`, ...);
%   this function resolves them to document ids and emits the relations.
%   See +ndi/+setup/+conv/+haley/import_V2_spec.json for a complete example.
%
%   RESULT fields:
%     documents     cell array of document structs, in creation order
%     ids           containers.Map, spec key -> document id
%     census        table: one row per class, with the count built
%     unrepresented struct array {kind, key, field, why}: spec content that
%                   has NO place in the V2 schema and was therefore NOT
%                   recorded. Reported, never silently dropped.
%
%   Options:
%     'DatasetId'   the dataset document's id. session_id is an edge
%                   (did-schema V_eta_relation_inheritance_plan.md), so the
%                   dataset entity's id IS the dataset's session id,
%                   SESSIONID, which every document here points at: the
%                   default is SESSIONID and any other value is an error
%                   (ndi:setup:V2:datasetId).
%     'Validate'    passed to did2.build (default true)
%     'Studies'     "include" (default): everything, studies too; "exclude":
%                   everything but the studies; "only": the studies and the
%                   relations filing them under the dataset alone, which needs
%                   'DatasetId' (given, or SESSIONID) (an import mints
%                   studies beside the sessions they group -- Haley decision
%                   #50 -- and the rest in its metadata stage). A study is
%                   `included_in` the dataset.
%
%   Errors did2:build:* when an entry does not fit the schema, and
%   ndi:setup:V2:* for spec problems (a duplicate key, a key that names
%   nothing, an entry of the wrong kind).
%
%   See also did2.build.document, ndi.setup.conv.haley.import_V2.

arguments
    spec
    sessionId (1,:) char
    options.DatasetId (1,:) char = ''
    options.Validate (1,1) logical = true
    options.Studies (1,1) string {mustBeMember(options.Studies, ["include", "exclude", "only"])} = "include"
end

if ischar(spec) || isstring(spec)
    spec = jsondecode(fileread(char(spec)));
end
% the dataset entity is the dataset's own record: its id is the session id
if isempty(options.DatasetId)
    options.DatasetId = sessionId;
elseif ~strcmp(options.DatasetId, sessionId)
    error('ndi:setup:V2:datasetId', ['''DatasetId'' %s is not the session id %s: ' ...
        'the dataset entity''s id is the dataset''s session id.'], options.DatasetId, sessionId);
end
state = struct();
state.docs = {};
state.ids = containers.Map();
state.kinds = containers.Map();
state.unrep = struct('kind', {}, 'key', {}, 'field', {}, 'why', {});
state.sid = sessionId;
state.validate = options.Validate;

if ~strcmp(options.Studies, 'only')
    % ---- entities, in dependency order ---------------------------------------
    for e = entries(spec, 'organizations')
        o = e{1};
        state = checkKnown(state, 'organization', o, {'name', 'short_name', 'identifiers', 'parent'});
        f = struct('name', o.name);
        f = putIf(f, 'short_name', o, 'short_name');
        f = putIds(f, o);
        state = add(state, 'organization', o.key, f, struct());
    end
    for e = entries(spec, 'organizations')
        o = e{1};
        if isfield(o, 'parent') && ~isempty(o.parent)
            state = relate(state, o.key, o.parent, 'suborganization_of', {'organization'}, {'organization'});
        end
    end

    for e = entries(spec, 'people')
        p = e{1};
        state = checkKnown(state, 'person', p, {'given_name', 'family_name', 'email', 'identifiers', 'affiliations'});
        f = struct();
        f = putIf(f, 'given_name', p, 'given_name');
        f = putIf(f, 'family_name', p, 'family_name');
        f = putIf(f, 'email', p, 'email');
        f = putIds(f, p);
        state = add(state, 'person', p.key, f, struct());
        for a = asCell(getOr(p, 'affiliations', {}))
            state = relate(state, p.key, a{1}, 'affiliated_with', {'person'}, {'organization'});
        end
    end

    for e = entries(spec, 'funding')
        g = e{1};
        state = checkKnown(state, 'funding', g, {'name', 'identifiers', 'funder', 'recipients'});
        f = putIds(struct('name', g.name), g);
        state = add(state, 'funding', g.key, f, struct());
        if isfield(g, 'funder')
            state = relate(state, g.key, g.funder, 'issued_by', {'funding'}, {'organization'});
        end
        for r = asCell(getOr(g, 'recipients', {}))
            state = relate(state, g.key, r{1}, 'awarded_to', {'funding'}, {'person', 'organization'});
        end
    end

    for e = entries(spec, 'publications')
        p = e{1};
        state = checkKnown(state, 'publication', p, {'name', 'publication_date', 'authors', 'identifiers'});
        f = struct('name', p.name);
        f = putIf(f, 'publication_date', p, 'publication_date');
        f = putIf(f, 'authors', p, 'authors');
        f = putIds(f, p);
        state = add(state, 'publication', p.key, f, struct());
    end

    % There is no web_resource entity (2026-10-08): a URL is an address for
    % the thing it names. A resource the dataset is `stored_at` becomes one of
    % the dataset's own identifiers; any other one is an entity of the `type`
    % the spec gives it (software, publication, ...).
    storedAt = asCell(getOr(getOr(spec, 'dataset', struct()), 'stored_at', {}));
    state.storedIds = {};
    state.storedHosts = {};
    for e = entries(spec, 'web_resources')
        w = e{1};
        if any(strcmp(w.key, storedAt))
            % a stored copy is one of the dataset's identifiers; its host is the
            % DATASET's `hosted_by` (did-schema 9bedceb, Jess 2026-10-15)
            state = checkKnown(state, 'web_resource', w, {'name', 'identifiers', 'host'}, ...
                struct('type', ''));
            if isfield(w, 'host')
                state.storedHosts{end+1} = w.host;
            end
            state.storedIds = [state.storedIds, storedIdentifiers(w)];
            state.ids(w.key) = '';
            state.kinds(w.key) = 'web_resource';
        else
            state = checkKnown(state, 'web_resource', w, {'name', 'identifiers', 'type'}, ...
                struct('host', 'the schema in use has no relation from a resource to its host'));
            if ~isfield(w, 'type')
                error('ndi:setup:V2:noType', ['web resource `%s` needs a `type` ' ...
                    '(software, publication, protocol, ...).'], w.key);
            end
            state = add(state, 'web_resource', w.key, putIds(struct('name', w.name), w), ...
                struct(), '', char(w.type));
        end
    end

    for e = entries(spec, 'software')
        s = e{1};
        % its maker: `developed_by` (did-schema 9bedceb, Jess 2026-10-15), not
        % `sold_by` -- free and open-source software was never sold
        state = checkKnown(state, 'software', s, {'name', 'version', 'identifiers', 'vendor'});
        f = putIf(struct('name', s.name), 'version', s, 'version');
        state = add(state, 'software', s.key, putIds(f, s), struct());
        if isfield(s, 'vendor')
            state = relate(state, s.key, s.vendor, 'developed_by', {'software'}, {'organization'});
        end
    end

    for e = entries(spec, 'products')
        p = e{1};
        state = checkKnown(state, 'product', p, {'name', 'catalog_number', 'lot_number', 'vendor'});
        f = struct('name', p.name);
        f = putIf(f, 'catalog_number', p, 'catalog_number');
        f = putIf(f, 'lot_number', p, 'lot_number');
        edges = struct();
        if isfield(p, 'vendor')
            edges.vendor_id = idOf(state, p.vendor, {'organization'});
        end
        state = add(state, 'product', p.key, f, edges);
    end

    for e = entries(spec, 'strains')
        s = e{1};
        % `node` (the strain's ontology term) and `biological_sex` are stated by
        % the import's assertions about the subjects of the strain, not held
        % on the strain entity (V2 `strain` has neither field).
        state = checkKnown(state, 'strain', s, {'name', 'species', 'genetic_strain_type', ...
            'description', 'genotype', 'identifiers', 'background', 'source'}, ...
            struct('node', '', 'biological_sex', ''));
        f = struct('name', s.name, 'species', s.species, ...
            'genetic_strain_type', asTerm(s.genetic_strain_type));
        % the genotype is a text assertion about the strain, variable
        % NCIT:C16631 Genotype (ndi.setup.V2.entityDocuments; Haley decision
        % #117), so it is queryable and reaches the strain's instances; the
        % description keeps human prose only
        if isfield(s, 'genotype') && ~isempty(s.genotype)
            f.genotype = char(s.genotype);
        end
        desc = char(getOr(s, 'description', ''));
        if ~isempty(desc)
            f.description = desc;
        end
        if isfield(s, 'node') && ~isempty(wormBaseId(char(s.node)))
            % the strain's WormBase id is one of its identifiers (
            % `WormBase:WBStrain00000001`, V_eta_entity_composition_plan.md sec. 6,
            % spelled per V_eta_prefix_spelling_plan.md), since a subject is
            % `instance_of` the strain rather than asserting it
            wb = struct('scheme', 'WormBase', 'value', wormBaseId(char(s.node)));
            s.identifiers = [asCell(getOr(s, 'identifiers', {})), {wb}];
        end
        f = putIds(f, s);
        edges = struct();
        if isfield(s, 'source')
            % The source repository's stock, as the strain's product (the current
            % schema's strain.product_id; see decision log entry 17).
            state = add(state, 'product', [s.key '#stock'], ...
                struct('name', sprintf('%s (stock)', s.name), 'catalog_number', s.name), ...
                struct('vendor_id', idOf(state, s.source, {'organization'})));
            edges.product_id = state.ids([s.key '#stock']);
        end
        bg = asCell(getOr(s, 'background', {}));
        if ~isempty(bg)
            edges.background_strain_id = cellfun(@(k) idOf(state, k, {'strain'}), bg, ...
                'UniformOutput', false);
        end
        state = add(state, 'strain', s.key, f, edges);
    end

    % Chemicals and formulations (Haley decision #56): what plates and seeding
    % suspensions are made of, dataset-level so every session's doses can point
    % at one copy. A chemical's `substance` is a term, {node, name} in the spec
    % (or a name alone); its `concentration` is the bottle's own strength. A formulation's
    % `ingredients` name chemicals, formulations or strains by key, each with
    % what the source gave (an added `mass` / `volume`, or a final
    % `concentration`), in order; `type` is the term of the standard recipe it
    % is (did-schema #84); `documented_by` cites
    % where the recipe is written down.
    for e = entries(spec, 'chemicals')
        c = e{1};
        state = checkKnown(state, 'chemical', c, {'substance', 'concentration', 'product'});
        v = struct('substance', asTerm(c.substance));
        v = putIf(v, 'concentration', c, 'concentration');
        edges = struct();
        if isfield(c, 'product')
            edges.product_id = idOf(state, c.product, {'product'});
        end
        state = add(state, 'chemical', c.key, struct('value', withSourceUnits(v)), edges);
    end
    for e = entries(spec, 'formulations')
        c = e{1};
        state = checkKnown(state, 'formulation', c, {'type', 'ingredients', 'ph', 'product', ...
            'documented_by'});
        v = struct();
        if isfield(c, 'type')
            v.type = asTerm(c.type);
        end
        ingredients = asCell(getOr(c, 'ingredients', {}));
        ids = cell(1, numel(ingredients));
        amounts = cell(1, numel(ingredients));
        for k = 1:numel(ingredients)
            g = ingredients{k};
            ids{k} = idOf(state, g.ingredient, {'chemical', 'formulation', 'strain'});
            amounts{k} = rmfield(g, 'ingredient');
        end
        if ~isempty(amounts)
            v.ingredients = amounts;
        end
        if isfield(c, 'ph')
            % a pH has no source unit: it is on its own scale, the canonical
            % `ph` (Jess Haley, 2026-10-21), so source_unit is left blank
            v.ph = struct('ph', c.ph, 'source_value', c.ph);
        end
        edges = struct();
        if ~isempty(ids)
            edges.ingredient_id = ids;
        end
        if isfield(c, 'product')
            edges.product_id = idOf(state, c.product, {'product'});
        end
        state = add(state, 'formulation', c.key, struct('value', withSourceUnits(v)), edges);
        for t = asCell(getOr(c, 'documented_by', {}))
            state = relate(state, c.key, t{1}, 'documented_by', {'formulation'}, {'web_resource'});
        end
    end

    for e = entries(spec, 'instruments')
        i = e{1};
        state = checkKnown(state, 'subject', i, {'local_identifier', 'name', 'description', 'product'});
        f = putIf(struct('local_identifier', i.local_identifier), 'description', i, 'description');
        f = putIf(f, 'name', i, 'name');
        state = add(state, 'subject', i.key, f, struct(), '', 'device');
        if isfield(i, 'product')
            state = relate(state, i.key, i.product, 'instance_of', {'subject'}, {'product'});
        end
    end

    % ---- the dataset, then everything that points at it -----------------------
    if ~isfield(spec, 'dataset')
        error('ndi:setup:V2:noDataset', 'The spec has no `dataset` section.');
    end
    d = spec.dataset;
    state = checkKnown(state, 'dataset', d, {'name', 'short_name', 'version', ...
        'version_innovation', 'description', 'how_to_cite', 'keyword', 'license', ...
        'accessibility', 'ethics_jurisdiction', 'experimental_approach', 'support_channel', ...
        'release_date', 'copyright_year', 'identifiers', 'authors', 'funding', 'cites', ...
        'stored_at', 'documented_by'});
    f = struct();
    for fn = {'name', 'short_name', 'version', 'version_innovation', 'description', ...
            'how_to_cite', 'keyword', 'license', 'accessibility', 'ethics_jurisdiction', ...
            'experimental_approach', 'support_channel', 'release_date', 'copyright_year'}
        f = putIf(f, fn{1}, d, fn{1});
    end
    f = putIds(f, d);
    if isfield(state, 'storedIds') && ~isempty(state.storedIds)
        % a stored copy is one of the dataset's addresses
        extra = cellfun(@(v) struct('scheme', 'URL', 'value', v), state.storedIds, ...
            'UniformOutput', false);
        if isfield(f, 'global_identifier')
            extra = [num2cell(f.global_identifier(:)'), extra];
        end
        f.global_identifier = did2.build.list(extra{:});
    end
    key = '#dataset';
    state = add(state, 'dataset', key, f, struct(), options.DatasetId);

    authors = asCell(getOr(d, 'authors', {}));
    for k = 1:numel(authors)
        a = authors{k};
        extra = struct('sequence', k);
        if isfield(a, 'roles')
            % CRediT role names: the builder fills each node from the field's
            % value set (directed_relation.roles), so a name must match it exactly
            extra.roles = did2.build.label(asCell(a.roles));
        end
        state = relate(state, key, a.person, 'has_author', {'dataset'}, {'person'}, extra);
    end
    % (`stored_at` is not a relation: a stored copy is one of the dataset's
    % identifiers, above)
    pairs = {'funding', 'funded_by', {'funding'}; 'cites', 'cites', {'publication'}; ...
            'documented_by', 'documented_by', {'web_resource'}}';
    for pair = pairs
        for t = asCell(getOr(d, pair{1}, {}))
            state = relate(state, key, t{1}, pair{2}, {'dataset'}, pair{3});
        end
    end
    if isfield(state, 'storedHosts') && ~isempty(state.storedHosts)
        % by index: `for` over an empty cell still runs once (on its 0x1 column)
        hosts = unique(state.storedHosts, 'stable');
        for k = 1:numel(hosts)
            state = relate(state, key, hosts{k}, 'hosted_by', {'dataset'}, {'organization'});
        end
    end
else
    % Studies alone (stage 3 of an import): they are filed under the dataset,
    % whose document another call builds, so its id is given, not made.
    if isempty(options.DatasetId)
        error('ndi:setup:V2:noDatasetId', ['''Studies'', "only" needs ''DatasetId'': ' ...
            'the dataset document the studies are filed under.']);
    end
    key = '#dataset';
    state.ids(key) = options.DatasetId;
    state.kinds(key) = 'dataset';
end

if ~strcmp(options.Studies, 'exclude')
    % A study's `design` is dropped (Jess Haley, 2026-10-21; proposed, not
    % signed: DID-schema V_eta_study_plan.md). A study may name a parent
    % study it is `included_in` (its key); otherwise it is filed under the
    % dataset. Every study is minted first, so a parent may be listed after
    % its child.
    studies = entries(spec, 'studies');
    for e = studies
        s = e{1};
        state = checkKnown(state, 'study', s, {'name', 'short_name', 'description', ...
            'factors', 'identifiers', 'included_in'}, ...
            struct('source_folder', '', 'source_condition', ''));   % import directives
        f = struct('name', s.name);
        f = putIf(f, 'short_name', s, 'short_name');
        f = putIf(f, 'description', s, 'description');
        f = putIf(f, 'factors', s, 'factors');
        state = add(state, 'study', s.key, putIds(f, s), struct());
    end
    for e = studies
        s = e{1};
        if isfield(s, 'included_in') && ~isempty(s.included_in)
            state = relate(state, s.key, s.included_in, 'included_in', {'study'}, {'study'});
        else
            state = relate(state, s.key, key, 'included_in', {'study'}, {'dataset'});
        end
    end
end

% ---- result -----------------------------------------------------------------
result = struct();
result.documents = state.docs;
result.ids = state.ids;
% counted under the per-leaf names (ndi.v2.leafName), so an `entity` counts as
% its type
classes = cellfun(@ndi.v2.leafName, state.docs, 'UniformOutput', false);
[u, ~, j] = unique(classes);
result.census = table(u(:), accumarray(j(:), 1), 'VariableNames', {'class', 'count'});
result.unrepresented = state.unrep;
end

% =============================================================================

function c = entries(spec, name)
arguments
    spec
    name {mustBeText}
end
if ~isfield(spec, name) || isempty(spec.(name))
    c = {};
    return;
end
c = asCell(spec.(name));
for k = 1:numel(c)
    if ~isstruct(c{k}) || ~isfield(c{k}, 'key') || isempty(c{k}.key)
        error('ndi:setup:V2:noKey', 'Entry %d of `%s` has no `key`.', k, name);
    end
end
end

function c = asCell(v)
arguments
    v
end
if isempty(v)
    c = {};
elseif iscell(v)
    c = reshape(v, 1, []);
elseif isstruct(v)
    c = num2cell(reshape(v, 1, []));
elseif ischar(v) || isstring(v)
    c = reshape(cellstr(v), 1, []);
else
    c = {v};
end
end

function v = getOr(s, name, default)
arguments
    s
    name {mustBeText}
    default
end
if isfield(s, name)
    v = s.(name);
else
    v = default;
end
end

function x = withSourceUnits(x)
% every `source_unit` the spec spells ('mg', 'g/L', 'mL') as the unit's
% registered term (ndi.setup.V2.sourceUnit; did-schema V_eta_source_unit_plan.md)
arguments
    x
end
if iscell(x)
    x = cellfun(@withSourceUnits, x, 'UniformOutput', false);
elseif isstruct(x)
    fn = fieldnames(x);
    for i = 1:numel(x)
        for j = 1:numel(fn)
            y = x(i).(fn{j});
            if strcmp(fn{j}, 'source_unit') && (ischar(y) || (isstring(y) && isscalar(y)))
                x(i).(fn{j}) = ndi.setup.V2.sourceUnit(y);
            else
                x(i).(fn{j}) = withSourceUnits(y);
            end
        end
    end
end
end

function f = putIf(f, fieldName, src, srcName)
arguments
    f
    fieldName {mustBeText}
    src
    srcName {mustBeText}
end
if isfield(src, srcName) && ~isempty(src.(srcName))
    f.(fieldName) = src.(srcName);
end
end

function f = putIds(f, src)
% A spec entry's `identifiers` [{scheme, value}] -> entity.global_identifier.
arguments
    f
    src
end
if ~isfield(src, 'identifiers') || isempty(src.identifiers)
    return;
end
ids = asCell(src.identifiers);
g = cell(1, numel(ids));
for k = 1:numel(ids)
    g{k} = struct('scheme', did2.build.label(ids{k}.scheme), 'value', ids{k}.value);
end
f.global_identifier = did2.build.list(g{:});
end

function t = asTerm(v)
arguments
    v
end
if isstruct(v)
    t = v;
else
    t = did2.build.label(v);
end
end

function state = checkKnown(state, kind, entry, known, noted)
% Record every spec field this kind cannot hold, instead of dropping it silently.
arguments
    state (1,1) struct
    kind {mustBeText}
    entry (1,1) struct
    known cell
    noted = struct()
end
% A spec key starting with `_` (`_verify`, `_note`) is an ANNOTATION for the
% reader, not data. jsondecode cannot keep a leading underscore in a field name
% and renames it `x_...`, so both spellings are recognised.
skip = [{'key'}, known];
names = fieldnames(entry);
for k = 1:numel(names)
    n = names{k};
    if any(strcmp(n, skip)) || startsWith(n, '_') || startsWith(n, 'x_')
        continue;
    end
    if isfield(noted, n)
        if isempty(noted.(n))
            continue;   % an import directive, not metadata
        end
        why = noted.(n);
    else
        why = sprintf('`%s` has no field or relation for it', kind);
    end
    state.unrep(end+1) = struct('kind', kind, 'key', char(string(getOr(entry, 'key', ''))), ...
        'field', n, 'why', why);
end
end

function id = idOf(state, key, kinds)
arguments
    state (1,1) struct
    key
    kinds cell
end
key = char(key);
if ~isKey(state.ids, key)
    error('ndi:setup:V2:unknownKey', 'The spec refers to `%s`, which no entry defines.', key);
end
if ~any(strcmp(state.kinds(key), kinds))
    error('ndi:setup:V2:wrongKind', '`%s` is a %s; expected %s.', key, ...
        state.kinds(key), strjoin(kinds, ' or '));
end
id = state.ids(key);
end

function state = add(state, className, key, fields, edges, id, type)
% TYPE: the entity type, for a subject (or web resource);
% ndi.setup.V2.entityDocuments.
arguments
    state (1,1) struct
    className {mustBeText}
    key
    fields
    edges
    id = ''
    type = ''
end
if isKey(state.ids, key)
    error('ndi:setup:V2:duplicateKey', 'The spec defines `%s` twice.', key);
end
entityKinds = {'organization', 'person', 'funding', 'publication', 'web_resource', ...
    'software', 'product', 'strain', 'subject', 'dataset', 'study'};
if any(strcmp(className, entityKinds))
    buildAs = className;
    if strcmp(className, 'web_resource') && ~isempty(type)
        buildAs = type;   % what the resource is
    end
    docs = ndi.setup.V2.entityDocuments(buildAs, fields, edges, 'SessionId', state.sid, ...
        'Id', id, 'Validate', state.validate, 'Type', type);
else
    docs = {did2.build.document(className, fields, 'SessionId', state.sid, ...
        'Edges', edges, 'Id', id, 'Validate', state.validate)};
end
state.docs = [state.docs, docs];
state.ids(key) = docs{1}.base.id;
state.kinds(key) = className;
end

function ids = storedIdentifiers(w)
% A stored copy's addresses: an NDI Cloud dataset page is `ndicloud:<id>`.
arguments
    w
end
ids = {};
for x = asCell(getOr(w, 'identifiers', {}))
    v = char(x{1}.value);
    tok = regexp(v, 'ndi-cloud\.com/datasets/([0-9a-f]{24})', 'tokens', 'once');
    if ~isempty(tok)
        ids{end+1} = ['ndicloud:' tok{1}]; %#ok<AGROW>
    else
        ids{end+1} = v; %#ok<AGROW>
    end
end
end

function state = relate(state, childKey, parentKey, relation, childKinds, parentKinds, extra)
arguments
    state (1,1) struct
    childKey
    parentKey
    relation {mustBeText}
    childKinds cell
    parentKinds cell
    extra = struct()
end
child = idOf(state, childKey, childKinds);
parent = idOf(state, parentKey, parentKinds);
opts = {};
if isfield(extra, 'sequence')
    opts = [opts, {'Sequence', extra.sequence}];
end
if isfield(extra, 'roles')
    opts = [opts, {'Fields', struct('roles', extra.roles)}];
end
doc = did2.build.directedRelation(child, parent, relation, 'SessionId', state.sid, ...
    'Validate', state.validate, opts{:});
state.docs{end+1} = doc;
end

function id = wormBaseId(node)
%WORMBASEID The WormBase strain id a strain node names ('WBStrain00000001'), or ''.
%   The node is written `WormBase:WBStrain00000001` (did-schema
%   V_eta_prefix_spelling_plan.md, signed 2026-10-19); the older
%   `WBStrain:00000001` is read too.
arguments
    node (1,:) char
end

id = '';
if startsWith(node, 'WBStrain:', 'IgnoreCase', true)
    id = ['WBStrain' node(numel('WBStrain:') + 1:end)];
elseif startsWith(node, 'WormBase:WBStrain', 'IgnoreCase', true)
    id = node(numel('WormBase:') + 1:end);
end
end
