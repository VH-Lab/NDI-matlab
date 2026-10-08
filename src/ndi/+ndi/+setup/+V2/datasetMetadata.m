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
%     'DatasetId'   the dataset document's id (default: a new one)
%     'Validate'    passed to did2.build (default true)
%     'Studies'     "include" (default): everything, studies too; "exclude":
%                   everything but the studies; "only": the studies and their
%                   `part_of` relations alone, which needs 'DatasetId' (an
%                   import mints studies beside the sessions they group --
%                   Haley decision #50 -- and the rest in its metadata stage)
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

    % On a schema with one entity class (2026-10-08) there is no web_resource:
    % a URL is an address for the thing it names. A resource the dataset is
    % `stored_at` becomes one of the dataset's own identifiers; any other one is
    % an entity of the `type` the spec gives it (software, publication, ...).
    merged = ndi.setup.V2.mergedEntities();
    storedAt = asCell(getOr(getOr(spec, 'dataset', struct()), 'stored_at', {}));
    state.storedIds = {};
    for e = entries(spec, 'web_resources')
        w = e{1};
        if ~merged
            state = checkKnown(state, 'web_resource', w, {'name', 'identifiers', 'host'}, ...
                struct('type', ''));
            state = add(state, 'web_resource', w.key, putIds(struct('name', w.name), w), struct());
            if isfield(w, 'host')
                state = relate(state, w.key, w.host, 'hosted_by', {'web_resource'}, {'organization'});
            end
        elseif any(strcmp(w.key, storedAt))
            state = checkKnown(state, 'web_resource', w, {'name', 'identifiers'}, ...
                struct('host', 'a stored copy is an identifier of the dataset; its host is not recorded', ...
                'type', ''));
            state.storedIds = [state.storedIds, storedIdentifiers(w)];
            state.ids(w.key) = '';
            state.kinds(w.key) = 'web_resource';
        else
            state = checkKnown(state, 'web_resource', w, {'name', 'identifiers', 'type'}, ...
                struct('host', 'the schema in use has no relation from a resource to its host'));
            if ~isfield(w, 'type')
                error('ndi:setup:V2:noType', ['web resource `%s` needs a `type` ' ...
                    '(software, publication, protocol, ...) on a schema with one entity class.'], w.key);
            end
            state = add(state, 'web_resource', w.key, putIds(struct('name', w.name), w), ...
                struct(), '', char(w.type));
        end
    end

    for e = entries(spec, 'software')
        s = e{1};
        state = checkKnown(state, 'software', s, {'name', 'version', 'identifiers'}, ...
            struct('vendor', 'V2 has no relation from software to its developer or vendor'));
        f = putIf(struct('name', s.name), 'version', s, 'version');
        state = add(state, 'software', s.key, putIds(f, s), struct());
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
        % V2 `strain` has no genotype field (nor does openMINDS Strain); the
        % genotype string is kept in the description rather than dropped.
        desc = strjoin(cellfun(@char, [asCell(getOr(s, 'genotype', {})), ...
            asCell(getOr(s, 'description', {}))], 'UniformOutput', false), '. ');
        if ~isempty(desc)
            f.description = desc;
        end
        if ndi.setup.V2.mergedEntities() && isfield(s, 'node') ...
                && startsWith(char(s.node), 'WBStrain:')
            % the strain's WormBase id is one of its identifiers (one entity class;
            % `wormbase:WBStrain00000001`, V_eta_entity_composition_plan.md sec. 6),
            % since a subject is `instance_of` the strain rather than asserting it
            wb = struct('scheme', 'WormBase', 'value', strrep(char(s.node), ':', ''));
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
    % at one copy. A chemical's `substance` is a term (a name until the ontology
    % lookup); its `concentration` is the bottle's own strength. A formulation's
    % `ingredients` name chemicals, formulations or strains by key, each with
    % what the source gave (an added `mass` / `volume`, or a final
    % `concentration`), in order; `type` names the standard recipe it is
    % (did-schema #84; left out on a schema without it); `documented_by` cites
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
        state = add(state, 'chemical', c.key, struct('value', v), edges);
    end
    formulationHasType = ndi.setup.V2.schemaHasField('formulation', 'value.type');
    for e = entries(spec, 'formulations')
        c = e{1};
        if formulationHasType
            state = checkKnown(state, 'formulation', c, {'type', 'ingredients', 'ph', 'product', ...
                'documented_by'});
        else
            state = checkKnown(state, 'formulation', c, {'ingredients', 'ph', 'product', ...
                'documented_by'}, struct('type', ...
                'the V2 schema in use has no formulation.value.type (did-schema PR #84)'));
        end
        v = struct();
        if formulationHasType && isfield(c, 'type')
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
            v.ph = struct('ph', c.ph, 'source_value', c.ph, 'source_unit', 'pH');
        end
        edges = struct();
        if ~isempty(ids)
            edges.ingredient_id = ids;
        end
        if isfield(c, 'product')
            edges.product_id = idOf(state, c.product, {'product'});
        end
        state = add(state, 'formulation', c.key, struct('value', v), edges);
        for t = asCell(getOr(c, 'documented_by', {}))
            state = relate(state, c.key, t{1}, 'documented_by', {'formulation'}, {'web_resource'});
        end
    end

    % `subject.name` arrived in did-schema PR #80; until the schema in use declares
    % it, an instrument's name is reported as unrepresented rather than built.
    subjectHasName = ndi.setup.V2.schemaHasField('subject', 'name');
    for e = entries(spec, 'instruments')
        i = e{1};
        if subjectHasName
            state = checkKnown(state, 'subject', i, {'local_identifier', 'name', 'description', 'product'});
        else
            state = checkKnown(state, 'subject', i, {'local_identifier', 'description', 'product'}, ...
                struct('name', 'the V2 schema in use has no subject.name (did-schema PR #80)'));
        end
        f = putIf(struct('local_identifier', i.local_identifier), 'description', i, 'description');
        if subjectHasName
            f = putIf(f, 'name', i, 'name');
        end
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
        'accessibility', 'ethics_assessment', 'experimental_approach', 'support_channel', ...
        'release_date', 'copyright_year', 'identifiers', 'authors', 'funding', 'cites', ...
        'stored_at', 'documented_by'});
    f = struct();
    for fn = {'name', 'short_name', 'version', 'version_innovation', 'description', ...
            'how_to_cite', 'keyword', 'license', 'accessibility', 'ethics_assessment', ...
            'experimental_approach', 'support_channel', 'release_date', 'copyright_year'}
        f = putIf(f, fn{1}, d, fn{1});
    end
    f = putIds(f, d);
    if isfield(state, 'storedIds') && ~isempty(state.storedIds)
        % a stored copy is one of the dataset's addresses (one entity class only)
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
            extra.roles = did2.build.label(asCell(a.roles));
        end
        state = relate(state, key, a.person, 'has_author', {'dataset'}, {'person'}, extra);
    end
    pairs = {'funding', 'funded_by', {'funding'}; 'cites', 'cites', {'publication'}; ...
            'stored_at', 'stored_at', {'web_resource'}; 'documented_by', 'documented_by', {'web_resource'}}';
    if ndi.setup.V2.mergedEntities()
        pairs = pairs(:, ~strcmp(pairs(1, :), 'stored_at'));   % now the dataset's identifiers
    end
    for pair = pairs
        for t = asCell(getOr(d, pair{1}, {}))
            state = relate(state, key, t{1}, pair{2}, {'dataset'}, pair{3});
        end
    end
else
    % Studies alone (stage 3 of an import): they are part_of the dataset,
    % whose document another call builds, so its id is given, not made.
    if isempty(options.DatasetId)
        error('ndi:setup:V2:noDatasetId', ['''Studies'', "only" needs ''DatasetId'': ' ...
            'the dataset document the studies are part_of.']);
    end
    key = '#dataset';
    state.ids(key) = options.DatasetId;
    state.kinds(key) = 'dataset';
end

if ~strcmp(options.Studies, 'exclude')
    for e = entries(spec, 'studies')
        s = e{1};
        state = checkKnown(state, 'study', s, {'name', 'short_name', 'description', ...
            'factors', 'design', 'identifiers'}, ...
            struct('source_folder', '', 'source_condition', ''));   % import directives
        f = struct('name', s.name);
        f = putIf(f, 'short_name', s, 'short_name');
        f = putIf(f, 'description', s, 'description');
        f = putIf(f, 'factors', s, 'factors');
        f = putIf(f, 'design', s, 'design');
        state = add(state, 'study', s.key, putIds(f, s), struct());
        state = relate(state, s.key, key, 'part_of', {'study'}, {'dataset'});
    end
end

% ---- result -----------------------------------------------------------------
result = struct();
result.documents = state.docs;
result.ids = state.ids;
classes = cellfun(@(x) x.document_class.class_name, state.docs, 'UniformOutput', false);
[u, ~, j] = unique(classes);
result.census = table(u(:), accumarray(j(:), 1), 'VariableNames', {'class', 'count'});
result.unrepresented = state.unrep;
end

% =============================================================================

function c = entries(spec, name)
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
if isfield(s, name)
    v = s.(name);
else
    v = default;
end
end

function f = putIf(f, fieldName, src, srcName)
if isfield(src, srcName) && ~isempty(src.(srcName))
    f.(fieldName) = src.(srcName);
end
end

function f = putIds(f, src)
% A spec entry's `identifiers` [{scheme, value}] -> entity.global_identifier.
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
if isstruct(v)
    t = v;
else
    t = did2.build.label(v);
end
end

function state = checkKnown(state, kind, entry, known, noted)
% Record every spec field this kind cannot hold, instead of dropping it silently.
if nargin < 5
    noted = struct();
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
% TYPE: the entity type, for a subject (or web resource) on a schema with one
% entity class; ndi.setup.V2.entityDocuments.
if nargin < 6
    id = '';
end
if nargin < 7
    type = '';
end
if isKey(state.ids, key)
    error('ndi:setup:V2:duplicateKey', 'The spec defines `%s` twice.', key);
end
entityKinds = {'organization', 'person', 'funding', 'publication', 'web_resource', ...
    'software', 'product', 'strain', 'subject', 'dataset', 'study'};
if any(strcmp(className, entityKinds))
    buildAs = className;
    if strcmp(className, 'web_resource') && ~isempty(type)
        buildAs = type;   % on a schema with one entity class, what the resource is
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
if nargin < 7
    extra = struct();
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
