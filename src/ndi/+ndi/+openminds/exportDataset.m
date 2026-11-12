function [dataset, datasetVersion, report] = exportDataset(documents, options)
%EXPORTDATASET One v2 dataset as an openMINDS Dataset and its one DatasetVersion.
%
%   [DATASET, DATASETVERSION, REPORT] = ndi.openminds.exportDataset(DOCUMENTS)
%   reads a v2 dataset -- DOCUMENTS, a cell array of its documents
%   (ndi.document, did2.document or property structs): the Data Set entity,
%   its statements and relations, and the people, organizations, grants and
%   publications those relations name -- and returns openMINDS_MATLAB
%   objects at the openMINDS version openMINDS_MATLAB puts on the path
%   (`latest`, as pinned by NDI's requirements):
%
%     DATASET         an openminds.core.products.Dataset
%     DATASETVERSION  an openminds.core.products.DatasetVersion whose
%                     `isVersionOf` is DATASET
%     REPORT          what was read, and everything not exported (below)
%
%   Decided (did-schema docs/plans/did_v2_go_forward_class_audit.md):
%     [openMINDS export answers] (Jess Haley, 2026-11-06): the export is a
%       function taking a v2 dataset and returning openMINDS_MATLAB objects,
%       targeting `latest` as pinned by openMINDS_MATLAB; `DatasetVersion`
%       is exported now, its fields from the dataset's assertions; the
%       corresponding author is not exported; each person's affiliations
%       are those listed for that person within the dataset (here: the
%       `affiliation` relations among DOCUMENTS).
%     [unmapped roles not exported] (2026-11-06): a CRediT role with no
%       openMINDS contribution type is left out and reported as not
%       exported.
%     [custodian exports as custodianship] (2026-11-07): the dataset's
%       `maintainer` relations export as a custodianship contribution.
%     [copyright year is a date assertion] (2026-11-07): Copyright.year is
%       the year of the dataset's `copyrightYear` date assertion; the
%       holder is its `copyrightHolder` relation.
%     [one dataset exports as Dataset and version] (2026-11-07): one Data
%       Set entity exports as one Dataset and one DatasetVersion that
%       `isVersionOf` it.
%     [documentation from subjectOf] (2026-11-07): `documentation` is the
%       dataset's `subjectOf` document (publication, protocol or software),
%       written with that document's global_identifier; with none, the
%       export reports documentation missing.
%
%   THE MAPPING IS THE CROSSWALK. Every property is read through did-schema's
%   did_v2_openminds_crosswalk.json (ndi.openminds.crosswalk): its
%   `target_kind` says where the v2 value is, `contribution_types` how each
%   contribution edge and CRediT role exports. Nothing is mapped here that
%   the crosswalk does not name.
%
%   NOTHING IS INVENTED OR DROPPED SILENTLY. A value the export cannot write
%   is a row of REPORT.notExported; a required openMINDS property with no
%   value is a row of REPORT.missing; a statement about the dataset or a
%   relation from it that no crosswalk row read is a row of REPORT.unread.
%
%   REPORT fields:
%     documents    how many documents were read (the denominator), and
%                  entities / statements / relations: how many of each
%     datasetId    the Data Set entity exported
%     openminds    the crosswalk's `openminds` block (the version it maps)
%     contributions struct array {type, contributors, edge}: each
%                  Contribution written
%     notExported  struct array {type, property, item, why}
%     missing      struct array {type, item, property}: required openMINDS
%                  properties left without a value
%     unread       struct array {id, kind, what}: the dataset's statements
%                  and relations no crosswalk row read
%     notBuilt     cellstr: DatasetVersion properties whose crosswalk row
%                  this export does not build (an open row, or a target
%                  kind it does not read); a value found for one is also a
%                  notExported row
%
%   Options:
%     'DatasetId'   the Data Set entity to export, when DOCUMENTS hold more
%                   than one (reference datasets, ndi.v2.referenceDatasets,
%                   are never chosen by default)
%     'SchemaPath'  the did-schema set (default DID_SCHEMA_PATH)
%
%   Errors ndi:openminds:exportDataset:noDataset when DOCUMENTS hold no
%   (or not the named) Data Set entity, and
%   ndi:openminds:exportDataset:datasetCount when they hold several and no
%   'DatasetId' is given.
%
%   See also ndi.openminds.crosswalk, ndi.v2.datasetDocuments.

arguments
    documents cell
    options.DatasetId (1,:) char = ''
    options.SchemaPath (1,:) char = getenv('DID_SCHEMA_PATH')
end

ctx = context(documents, options.SchemaPath);
dsIndex = chooseDataset(ctx, options.DatasetId);
dsDoc = ctx.P{dsIndex};
dsId = ctx.ids{dsIndex};

datasetVersion = openminds.core.products.DatasetVersion();
made(ctx, 'DatasetVersion', dsId, datasetVersion);
rows = ctx.cw.types.DatasetVersion.properties;
notBuilt = {};

% the rows that are fields, assertions and identifiers of the entity
notBuilt = [notBuilt, fillFromRows(ctx, datasetVersion, 'DatasetVersion', dsDoc, rows)];

% the rows that are relations, the implied one and the projection; the
% contributions first, since the affiliations are those of the people
% they name
if isfield(rows, 'contribution')
    exportContributions(ctx, datasetVersion, dsId, rows.contribution);
end
names = fieldnames(rows);
for k = 1:numel(names)
    prop = names{k};
    row = rows.(prop);
    switch row.target_kind
        case 'relation'
            switch prop
                case {'contribution', 'contributorAffiliation'}
                    % before and after this loop
                case 'copyright'
                    exportCopyright(ctx, datasetVersion, dsId, row);
                case 'documentation'
                    exportDocumentation(ctx, datasetVersion, dsId, row);
                case 'funding'
                    exportFunding(ctx, datasetVersion, dsId, row);
                case 'relatedPublication'
                    exportRelatedPublications(ctx, datasetVersion, dsId, row);
                otherwise
                    notBuilt{end+1} = prop; %#ok<AGROW>
                    rels = relationsFrom(ctx, dsId, row.ndi_target);
                    for j = 1:numel(rels)
                        markRead(ctx, rels(j).id);
                        note(ctx, 'DatasetVersion', prop, describeRelation(ctx, rels(j)), ...
                            sprintf('this export does not build `%s` (its crosswalk row is relation `%s`)', ...
                            prop, char(strjoin(cellstr(row.ndi_target), ', '))));
                    end
            end
        case 'implied'
            if strcmp(prop, 'isVersionOf')
                % filled once the Dataset exists, below
                continue;
            end
            notBuilt{end+1} = prop; %#ok<AGROW>
        case 'projection'
            notBuilt{end+1} = prop; %#ok<AGROW>
    end
end
if isfield(rows, 'contributorAffiliation')
    exportAffiliations(ctx, datasetVersion, rows.contributorAffiliation);
end

% ---- the Dataset: the same entity, version-independent ----------------------
dataset = openminds.core.products.Dataset();
made(ctx, 'Dataset', dsId, dataset);
shared = intersect(fieldnames(rows), properties(dataset), 'stable');
for k = 1:numel(shared)
    prop = shared{k};
    if strcmp(prop, 'digitalIdentifier')
        if hasValue(datasetVersion.digitalIdentifier)
            note(ctx, 'Dataset', prop, dsId, ['the dataset''s DOI is written on the ' ...
                'DatasetVersion; whether the version-independent Dataset carries it too ' ...
                'is not decided']);
        end
        continue;
    end
    v = datasetVersion.(prop);
    if hasValue(v)
        assign(ctx, dataset, 'Dataset', prop, v, dsId);
    end
end
assign(ctx, datasetVersion, 'DatasetVersion', 'isVersionOf', dataset, dsId);

% ---- the report ------------------------------------------------------------------
report = struct();
report.documents = numel(ctx.P);
report.entities = nnz(ctx.isEntity);
report.statements = nnz(ctx.isStatement);
report.relations = nnz(ctx.isRelation);
report.datasetId = dsId;
report.openminds = ctx.cw.openminds;
report.contributions = ctx.log('contributions');
report.notExported = ctx.log('notExported');
report.missing = missingRequired(ctx);
report.unread = unread(ctx, dsId);
report.notBuilt = unique(notBuilt, 'stable');
end

% =============================================================================
% the documents
% =============================================================================

function ctx = context(documents, schemaPath)
arguments
    documents cell
    schemaPath (1,:) char
end
ctx = struct();
ctx.schemaPath = schemaPath;
ctx.cw = ndi.openminds.crosswalk(schemaPath);
ctx.P = cellfun(@ndi.v2.props, documents, 'UniformOutput', false);
n = numel(ctx.P);
ctx.ids = cell(1, n);
ctx.isEntity = false(1, n);
ctx.isStatement = false(1, n);
ctx.isRelation = false(1, n);
ctx.about = repmat({''}, 1, n);   % a statement's entity_id
ctx.child = repmat({''}, 1, n);   % a relation's child_id
for k = 1:n
    p = ctx.P{k};
    ctx.ids{k} = char(p.base.id);
    cls = '';
    if isfield(p, 'document_class') && isfield(p.document_class, 'class_name')
        cls = char(p.document_class.class_name);
    end
    ctx.isEntity(k) = strcmp(cls, 'entity');
    ctx.isRelation(k) = strcmp(cls, 'directed_relation');
    ctx.isStatement(k) = isfield(p, 'statement');
    if ctx.isStatement(k)
        e = ndi.v2.edgeIds(p, 'entity_id');
        if ~isempty(e), ctx.about{k} = e{1}; end
    elseif ctx.isRelation(k)
        c = ndi.v2.edgeIds(p, 'child_id');
        if ~isempty(c), ctx.child{k} = c{1}; end
    end
end
ctx.byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = n:-1:1
    ctx.byId(ctx.ids{k}) = k;   % the first document of an id wins
end
ctx.objects = containers.Map();   % entity id -> its openMINDS object
ctx.read = containers.Map();      % document id -> true, once a row read it
ctx.log = containers.Map();
ctx.log('notExported') = struct('type', {}, 'property', {}, 'item', {}, 'why', {});
ctx.log('contributions') = struct('type', {}, 'contributors', {}, 'edge', {});
ctx.log('made') = cell(0, 3);     % {type, entity id, object}
end

function k = chooseDataset(ctx, datasetId)
arguments
    ctx (1,1) struct
    datasetId (1,:) char
end
isDataset = false(size(ctx.ids));
for j = find(ctx.isEntity)
    isDataset(j) = ndi.v2.vocabIs('entity_type', entityType(ctx.P{j}), 'dataset', ctx.schemaPath);
end
if ~isempty(datasetId)
    k = find(isDataset & strcmp(ctx.ids, datasetId), 1);
    if isempty(k)
        error('ndi:openminds:exportDataset:noDataset', ...
            'The documents hold no Data Set entity %s.', datasetId);
    end
    return;
end
reference = ndi.v2.referenceDatasets(ctx.P);
candidates = find(isDataset & ~ismember(ctx.ids, reference));
if isempty(candidates)
    error('ndi:openminds:exportDataset:noDataset', ...
        'The %d documents hold no Data Set entity (reference datasets left out: %d).', ...
        numel(ctx.ids), numel(reference));
end
if numel(candidates) > 1
    error('ndi:openminds:exportDataset:datasetCount', ...
        'The documents hold %d Data Set entities (%s); name one with ''DatasetId''.', ...
        numel(candidates), strjoin(ctx.ids(candidates), ', '));
end
k = candidates;
end

function t = entityType(p)
arguments
    p (1,1) struct
end
t = ndi.v2.blockOf(p, 'entity', 'type', '');
end

function p = docOf(ctx, id)
arguments
    ctx (1,1) struct
    id (1,:) char
end
p = [];
if isKey(ctx.byId, id)
    p = ctx.P{ctx.byId(id)};
end
end

function rels = relationsFrom(ctx, childId, relationNames)
%RELATIONSFROM The directed relations whose child is CHILDID and whose
%   relation is one of RELATIONNAMES (the crosswalk's registered names,
%   compared by node through ndi.v2.vocabIs), in `order`.
arguments
    ctx (1,1) struct
    childId (1,:) char
    relationNames
end
relationNames = cellstr(relationNames);
rels = struct('id', {}, 'parent', {}, 'order', {}, 'roles', {}, 'relation', {});
for k = find(ctx.isRelation & strcmp(ctx.child, childId))
    p = ctx.P{k};
    relation = ndi.v2.blockOf(p, 'directed_relation', 'relation', '');
    if ~ndi.v2.vocabIs('relation', relation, relationNames, ctx.schemaPath)
        continue;
    end
    parent = ndi.v2.edgeIds(p, 'parent_id');
    if isempty(parent)
        continue;
    end
    order = ndi.v2.blockOf(p, 'directed_relation', 'order', -1);
    if isempty(order)
        order = -1;
    end
    roles = ndi.v2.blockOf(p, 'directed_relation', 'roles', []);
    rels(end+1) = struct('id', ctx.ids{k}, 'parent', parent{1}, 'order', double(order(1)), ...
        'roles', {roles}, 'relation', {relation}); %#ok<AGROW>
end
if ~isempty(rels)
    % ordered edges first, by their order; unordered ones after, as found
    o = [rels.order];
    o(o < 0) = Inf;
    [~, ix] = sort(o);
    rels = rels(ix);
end
end

function s = statementsAbout(ctx, entityId, variableName)
%STATEMENTSABOUT The statements about ENTITYID whose variable is the
%   registered term VARIABLENAME (by its node, else by name).
arguments
    ctx (1,1) struct
    entityId (1,:) char
    variableName (1,:) char
end
reg = ndi.setup.V2.registeredTerm('', variableName);
patterns = {variableName};
if isfield(reg, 'node') && ~isempty(reg.node)
    patterns{end+1} = char(reg.node);
end
s = {};
for k = find(ctx.isStatement & strcmp(ctx.about, entityId))
    p = ctx.P{k};
    v = ndi.v2.blockOf(p, 'statement', 'variable', []);
    if isempty(v) || ~ndi.v2.matchTerm(v, patterns)
        continue;
    end
    s{end+1} = p; %#ok<AGROW>
end
end

function vals = valuesOf(statements, kind)
%VALUESOF The value cells of STATEMENTS of value kind KIND ('term', 'text',
%   'date'), as a cell; a statement of another kind gives none.
arguments
    statements cell
    kind (1,:) char
end
vals = {};
for k = 1:numel(statements)
    raw = ndi.v2.blockOf(statements{k}, kind, 'value', []);
    if isempty(raw)
        continue;
    end
    if isstruct(raw)
        raw = num2cell(raw);
    elseif ~iscell(raw)
        raw = {raw};
    end
    vals = [vals, reshape(raw, 1, [])]; %#ok<AGROW>
end
end

function [scheme, local, text] = identifiers(p)
%IDENTIFIERS An entity's global identifiers: each one's scheme (the CURIE
%   prefix's registry key, lower case, or 'IRI' for a URL) and local part.
arguments
    p (1,1) struct
end
g = ndi.v2.blockOf(p, 'entity', 'global_identifier', {});
if isempty(g)
    text = cell(1, 0);
else
    text = reshape(cellstr(string(g)), 1, []);
end
scheme = cell(size(text));
local = cell(size(text));
for k = 1:numel(text)
    t = strtrim(text{k});
    if ~isempty(regexp(t, '^https?://', 'once'))
        scheme{k} = 'IRI';
        local{k} = t;
        continue;
    end
    c = strfind(t, ':');
    if isempty(c)
        scheme{k} = '';
        local{k} = t;
        continue;
    end
    key = ndi.v2.curieKey(t);
    kc = strfind(key, ':');
    scheme{k} = lower(key(1:kc(1)-1));
    local{k} = t(c(1)+1:end);
end
end

function markRead(ctx, id)
arguments
    ctx (1,1) struct
    id (1,:) char
end
ctx.read(id) = true;
end

function markStatements(ctx, statements)
arguments
    ctx (1,1) struct
    statements cell
end
for k = 1:numel(statements)
    markRead(ctx, char(statements{k}.base.id));
end
end

% =============================================================================
% the entity's own rows: fields, assertions and global identifiers
% =============================================================================

function notBuilt = fillFromRows(ctx, obj, typeName, p, rows)
%FILLFROMROWS Fill OBJ (an openMINDS TYPENAME) from the entity P through the
%   crosswalk ROWS of kind field, assertion and global_identifier. Rows of
%   other kinds are the caller's. NOTBUILT lists the rows read but not built.
arguments
    ctx (1,1) struct
    obj
    typeName (1,:) char
    p (1,1) struct
    rows (1,1) struct
end
notBuilt = {};
id = char(p.base.id);
[scheme, local, idText] = identifiers(p);
names = fieldnames(rows);
for k = 1:numel(names)
    prop = names{k};
    row = rows.(prop);
    switch row.target_kind
        case 'field'
            v = ndi.v2.blockOf(p, 'entity', row.ndi_target, '');
            if ~isempty(v)
                assign(ctx, obj, typeName, prop, string(v), id);
            end
        case 'assertion'
            s = statementsAbout(ctx, id, row.ndi_target);
            if isempty(s)
                continue;
            end
            markStatements(ctx, s);
            exportAssertion(ctx, obj, typeName, prop, row, s, id);
        case 'global_identifier'
            target = lower(char(row.ndi_target));
            if strcmpi(target, 'IRI') || ~any(strcmp(target, {'doi', 'orcid', 'ror'}))
                % an IRI is not told apart from other addresses, and an
                % NDI Cloud copy has no FileRepository source (both open in
                % the crosswalk): reported, never written
                notBuilt{end+1} = prop; %#ok<AGROW>
                for j = find(strcmpi(scheme, target))
                    note(ctx, typeName, prop, idText{j}, sprintf(['this export does not ' ...
                        'build `%s` from a `%s` identifier (crosswalk row open)'], prop, target));
                end
                continue;
            end
            values = {};
            for j = find(strcmp(scheme, target))
                [o, why] = identifierObject(target, local{j});
                if isempty(o)
                    note(ctx, typeName, prop, idText{j}, why);
                else
                    values{end+1} = o; %#ok<AGROW>
                end
            end
            if ~isempty(values)
                assign(ctx, obj, typeName, prop, asValue(values), id);
            end
    end
end
end

function exportAssertion(ctx, obj, typeName, prop, row, s, id)
arguments
    ctx (1,1) struct
    obj
    typeName (1,:) char
    prop (1,:) char
    row (1,1) struct
    s cell
    id (1,:) char
end
switch row.value_kind
    case 'text'
        vals = valuesOf(s, 'text');
        t = strings(1, 0);
        for j = 1:numel(vals)
            v = vals{j};
            if isstruct(v) && isfield(v, 'text')
                v = v.text;
            end
            t(end+1) = string(v); %#ok<AGROW>
        end
        if isempty(t)
            return;
        end
        if strcmp(prop, 'contactInformation')
            % openMINDS ContactInformation{email}
            c = openminds.core.actors.ContactInformation();
            if assign(ctx, c, 'ContactInformation', 'email', t, id)
                made(ctx, 'ContactInformation', id, c);
                assign(ctx, obj, typeName, prop, c, id);
            end
            return;
        end
        assign(ctx, obj, typeName, prop, t, id);
    case 'date'
        vals = valuesOf(s, 'date');
        d = datetime.empty;
        for j = 1:numel(vals)
            v = vals{j};
            if ~isstruct(v) || ~isfield(v, 'instant')
                continue;
            end
            instant = char(string(v.instant));
            precision = '';
            if isfield(v, 'precision')
                precision = char(string(v.precision));
            end
            if ~strcmp(precision, 'day') || numel(instant) < 10
                note(ctx, typeName, prop, instant, sprintf(['a date of precision `%s`: ' ...
                    'openMINDS takes a day (YYYY-MM-DD), and none is invented'], precision));
                continue;
            end
            d(end+1) = datetime(instant(1:10), 'InputFormat', 'yyyy-MM-dd'); %#ok<AGROW>
        end
        if ~isempty(d)
            assign(ctx, obj, typeName, prop, d, id);
        end
    case 'term'
        vals = valuesOf(s, 'term');
        instances = {};
        for j = 1:numel(vals)
            [inst, why] = termInstance(ctx, vals{j});
            if isempty(inst)
                note(ctx, typeName, prop, ndi.v2.termName(vals{j}), why);
            else
                instances{end+1} = inst; %#ok<AGROW>
            end
        end
        if ~isempty(instances)
            assign(ctx, obj, typeName, prop, asValue(instances), id);
        end
    otherwise
        note(ctx, typeName, prop, id, sprintf('a `%s` assertion: this export reads text, date and term values', ...
            row.value_kind));
end
end

function [inst, why] = termInstance(ctx, t)
%TERMINSTANCE The openMINDS instance a v2 term is: its node when that is an
%   openMINDS instance (openminds:<terminology>/<name>), else the openMINDS
%   instance the term registry's `equivalent` column lists for it.
arguments
    ctx (1,1) struct
    t
end
inst = [];
why = '';
node = '';
if isstruct(t) && isfield(t, 'node')
    node = strtrim(char(string(t.node)));
end
curie = '';
if startsWith(node, 'openminds:', 'IgnoreCase', true)
    curie = node;
elseif ~isempty(node)
    same = equivalents(ctx, node);
    om = same(startsWith(same, 'openminds:', 'IgnoreCase', true));
    if numel(om) == 1
        curie = om{1};
    elseif numel(om) > 1
        why = sprintf('the term registry lists %d openMINDS equivalents for %s', numel(om), node);
        return;
    end
end
if isempty(curie)
    why = sprintf(['term %s is no openMINDS instance and the term registry lists no ' ...
        'openMINDS equivalent for it'], node);
    return;
end
iri = "https://openminds.om-i.org/instances/" + string(curie(numel('openminds:')+1:end));
try
    inst = openminds.instanceFromIRI(iri);
catch ME
    inst = [];
    why = sprintf('openMINDS has no instance %s (%s)', iri, ME.message);
end
end

function same = equivalents(ctx, node)
arguments
    ctx (1,1) struct
    node (1,:) char
end
if ~isKey(ctx.log, 'equivalent')
    m = containers.Map();
    f = ndi.v2.schemaFile(ctx.schemaPath, 'did_v2_term_registry.json');
    if isfile(f)
        r = jsondecode(fileread(f));
        terms = r.terms;
        if isstruct(terms)
            terms = num2cell(terms);
        end
        for k = 1:numel(terms)
            e = terms{k};
            if isfield(e, 'node') && ~isempty(e.node) && isfield(e, 'equivalent') && ~isempty(e.equivalent)
                m(ndi.v2.curieKey(char(e.node))) = cellstr(string(e.equivalent));
            end
        end
    end
    ctx.log('equivalent') = m;
end
m = ctx.log('equivalent');
key = ndi.v2.curieKey(node);
if isKey(m, key)
    same = reshape(m(key), 1, []);
else
    same = {};
end
end

function [obj, why] = identifierObject(scheme, local)
%IDENTIFIEROBJECT The openMINDS object for one global identifier, or [] and
%   the reason (a scheme openMINDS has no object for here, or a value its
%   pattern refuses).
arguments
    scheme (1,:) char
    local (1,:) char
end
obj = [];
why = '';
try
    switch scheme
        case 'doi'
            obj = openminds.core.digitalidentifier.DOI('identifier', "https://doi.org/" + string(local));
        case 'orcid'
            obj = openminds.core.digitalidentifier.ORCID('identifier', "https://orcid.org/" + string(local));
        case 'ror'
            obj = openminds.core.digitalidentifier.RORID('identifier', "https://ror.org/" + string(local));
        case 'isbn'
            obj = openminds.core.digitalidentifier.ISBN('identifier', string(local));
        case 'IRI'
            obj = openminds.core.miscellaneous.WebResource('IRI', string(local));
        otherwise
            why = sprintf('no openMINDS identifier object for scheme `%s`', scheme);
    end
catch ME
    obj = [];
    why = sprintf('openMINDS refused identifier %s:%s (%s)', scheme, local, ME.message);
end
end

% =============================================================================
% people, organizations, grants
% =============================================================================

function obj = actorOf(ctx, id, prop, owner)
%ACTOROF The openMINDS Person or Organization for the entity ID (made once),
%   or [] (with a notExported row against OWNER.PROP) for any other entity.
arguments
    ctx (1,1) struct
    id (1,:) char
    prop (1,:) char
    owner (1,:) char = 'DatasetVersion'
end
obj = [];
if isKey(ctx.objects, id)
    obj = ctx.objects(id);
    return;
end
p = docOf(ctx, id);
if isempty(p)
    note(ctx, owner, prop, id, 'the related entity is not among the documents');
    return;
end
t = entityType(p);
if ndi.v2.vocabIs('entity_type', t, 'person', ctx.schemaPath)
    obj = openminds.core.actors.Person();
    ctx.objects(id) = obj;
    made(ctx, 'Person', id, obj);
    fillFromRows(ctx, obj, 'Person', p, ctx.cw.types.Person.properties);
elseif ndi.v2.vocabIs('entity_type', t, 'organization', ctx.schemaPath)
    obj = openminds.core.actors.Organization();
    ctx.objects(id) = obj;
    made(ctx, 'Organization', id, obj);
    rows = ctx.cw.types.Organization.properties;
    fillFromRows(ctx, obj, 'Organization', p, rows);
    if isfield(rows, 'hasParent') && strcmp(rows.hasParent.target_kind, 'relation')
        parents = relationsFrom(ctx, id, rows.hasParent.ndi_target);
        objs = {};
        for j = 1:numel(parents)
            o = actorOf(ctx, parents(j).parent, 'hasParent', 'Organization');
            if isa(o, 'openminds.core.actors.Organization')
                objs{end+1} = o; %#ok<AGROW>
            end
        end
        if ~isempty(objs)
            assign(ctx, obj, 'Organization', 'hasParent', [objs{:}], id);
        end
    end
else
    note(ctx, owner, prop, id, sprintf('the related entity is of type `%s`, not a person or organization', ...
        ndi.v2.termName(t)));
end
end

function exportContributions(ctx, dv, dsId, row)
%EXPORTCONTRIBUTIONS openMINDS Contribution{contributor, type}, from each
%   contribution edge the crosswalk's row names, as its `contribution_types`
%   says: an edge with one openMINDS type (author: authoring; maintainer:
%   custodianship) is one Contribution listing its parties in edge order;
%   a `contributor` edge is one Contribution per CRediT role on it, typed
%   from `contribution_types.roles`. A role marked `export: false` is
%   reported, not exported ([unmapped roles not exported]; the
%   corresponding author, G108(3)).
arguments
    ctx (1,1) struct
    dv
    dsId (1,:) char
    row (1,1) struct
end
edges = ctx.cw.contribution_types.edges;
roleRows = ctx.cw.contribution_types.roles;
if isstruct(roleRows)
    roleRows = num2cell(roleRows);
end
contributions = {};
for e = reshape(cellstr(row.ndi_target), 1, [])
    edge = e{1};
    rels = relationsFrom(ctx, dsId, edge);
    if isempty(rels)
        continue;
    end
    for j = 1:numel(rels)
        markRead(ctx, rels(j).id);
    end
    if ~isfield(edges, edge)
        for j = 1:numel(rels)
            note(ctx, 'DatasetVersion', 'contribution', describeRelation(ctx, rels(j)), ...
                sprintf('the crosswalk''s contribution_types has no row for edge `%s`', edge));
        end
        continue;
    end
    if isfield(edges.(edge), 'openminds')
        % one typed Contribution listing every party of this edge, in order
        parties = {};
        partyIds = {};
        for j = 1:numel(rels)
            o = actorOf(ctx, rels(j).parent, 'contribution');
            if ~isempty(o)
                parties{end+1} = o; %#ok<AGROW>
                partyIds{end+1} = rels(j).parent; %#ok<AGROW>
            end
            for r = rolesOf(rels(j).roles)
                note(ctx, 'DatasetVersion', 'contribution', ...
                    sprintf('%s on %s', ndi.v2.termName(r{1}), describeRelation(ctx, rels(j))), ...
                    sprintf(['a CRediT role on a `%s` edge: the crosswalk maps roles on ' ...
                    '`contributor` edges only'], edge));
            end
        end
        if ~isempty(parties)
            c = contribution(ctx, parties, partyIds, char(edges.(edge).openminds.name), edge, dsId);
            if ~isempty(c)
                contributions{end+1} = c; %#ok<AGROW>
            end
        end
        continue;
    end
    % a contributor edge: one Contribution per CRediT role
    for j = 1:numel(rels)
        roles = rolesOf(rels(j).roles);
        if isempty(roles)
            note(ctx, 'DatasetVersion', 'contribution', describeRelation(ctx, rels(j)), ...
                sprintf('a `%s` edge with no CRediT role: no contribution type to export it as', edge));
            continue;
        end
        o = actorOf(ctx, rels(j).parent, 'contribution');
        if isempty(o)
            continue;
        end
        for r = roles
            rr = roleRow(roleRows, r{1});
            roleName = ndi.v2.termName(r{1});
            if isempty(rr)
                note(ctx, 'DatasetVersion', 'contribution', ...
                    sprintf('%s on %s', roleName, describeRelation(ctx, rels(j))), ...
                    'the role is not in the crosswalk''s contribution_types.roles');
                continue;
            end
            if ~isfield(rr, 'export') || ~rr.export || ~isfield(rr, 'openminds')
                note(ctx, 'DatasetVersion', 'contribution', ...
                    sprintf('%s on %s', roleName, describeRelation(ctx, rels(j))), ...
                    sprintf(['CRediT role "%s" is not exported: the crosswalk marks it ' ...
                    '`export: false` (match: %s)'], roleName, char(string(rr.match))));
                continue;
            end
            c = contribution(ctx, {o}, {rels(j).parent}, char(rr.openminds.name), edge, dsId);
            if ~isempty(c)
                contributions{end+1} = c; %#ok<AGROW>
            end
        end
    end
end
if ~isempty(contributions)
    assign(ctx, dv, 'DatasetVersion', 'contribution', [contributions{:}], dsId);
end
end

function c = contribution(ctx, parties, partyIds, typeName, edge, dsId)
arguments
    ctx (1,1) struct
    parties cell
    partyIds cell
    typeName (1,:) char
    edge (1,:) char
    dsId (1,:) char
end
c = openminds.core.actors.Contribution();
try
    t = openminds.controlledterms.ContributionType(typeName);
catch ME
    note(ctx, 'DatasetVersion', 'contribution', sprintf('%s (%s)', typeName, edge), ...
        sprintf('openMINDS has no ContributionType "%s" (%s)', typeName, ME.message));
    c = [];
    return;
end
ok = assign(ctx, c, 'Contribution', 'contributor', asValue(parties), dsId);
ok = ok && assign(ctx, c, 'Contribution', 'type', t, dsId);
if ~ok
    c = [];
    return;
end
made(ctx, 'Contribution', dsId, c);
entries = ctx.log('contributions');
entries(end+1) = struct('type', typeName, 'contributors', {partyIds}, 'edge', edge);
ctx.log('contributions') = entries;
end

function r = rolesOf(roles)
% the roles of an edge as a row cell of terms
arguments
    roles
end
if isempty(roles)
    r = {};
elseif isstruct(roles)
    r = reshape(num2cell(roles), 1, []);
elseif iscell(roles)
    r = reshape(roles, 1, []);
else
    r = reshape(cellstr(string(roles)), 1, []);
end
end

function rr = roleRow(roleRows, role)
% the crosswalk row for a stored CRediT role: by node, else by name
arguments
    roleRows cell
    role
end
rr = [];
node = '';
name = ndi.v2.termName(role);
if isstruct(role) && isfield(role, 'node')
    node = strtrim(char(string(role.node)));
end
for k = 1:numel(roleRows)
    x = roleRows{k}.role;
    if ~isempty(node) && isfield(x, 'node') && ~isempty(x.node) ...
            && strcmp(ndi.v2.curieKey(node), ndi.v2.curieKey(char(x.node)))
        rr = roleRows{k};
        return;
    end
end
for k = 1:numel(roleRows)
    if strcmpi(char(roleRows{k}.role.name), name)
        rr = roleRows{k};
        return;
    end
end
end

function exportAffiliations(ctx, dv, row)
%EXPORTAFFILIATIONS openMINDS Affiliation{person, organization}, one per
%   person exported in a contribution: the organizations its `affiliation`
%   relations among the documents name (G108(4): a person's affiliations
%   are those listed for that person within the dataset).
arguments
    ctx (1,1) struct
    dv
    row (1,1) struct
end
entries = ctx.log('contributions');
people = unique([entries.contributors], 'stable');
affiliations = {};
for k = 1:numel(people)
    pid = people{k};
    person = ctx.objects(pid);
    if ~isa(person, 'openminds.core.actors.Person')
        continue;
    end
    rels = relationsFrom(ctx, pid, row.ndi_target);
    orgs = {};
    for j = 1:numel(rels)
        markRead(ctx, rels(j).id);
        o = actorOf(ctx, rels(j).parent, 'contributorAffiliation');
        if isa(o, 'openminds.core.actors.Organization')
            orgs{end+1} = o; %#ok<AGROW>
        elseif ~isempty(o)
            note(ctx, 'DatasetVersion', 'contributorAffiliation', describeRelation(ctx, rels(j)), ...
                'an affiliation''s parent must be an organization');
        end
    end
    if isempty(orgs)
        continue;
    end
    a = openminds.core.actors.Affiliation();
    if assign(ctx, a, 'Affiliation', 'person', person, pid) && ...
            assign(ctx, a, 'Affiliation', 'organization', [orgs{:}], pid)
        made(ctx, 'Affiliation', pid, a);
        affiliations{end+1} = a; %#ok<AGROW>
    end
end
if ~isempty(affiliations)
    assign(ctx, dv, 'DatasetVersion', 'contributorAffiliation', [affiliations{:}], '');
end
end

function exportCopyright(ctx, dv, dsId, row)
%EXPORTCOPYRIGHT openMINDS Copyright{holder, year}: the holder from the
%   dataset's `copyrightHolder` relations, the year from its
%   `copyrightYear` date assertion ([copyright year is a date assertion]).
arguments
    ctx (1,1) struct
    dv
    dsId (1,:) char
    row (1,1) struct
end
parts = row.parts;
holders = {};
rels = relationsFrom(ctx, dsId, parts.holder.ndi_target);
for j = 1:numel(rels)
    markRead(ctx, rels(j).id);
    o = actorOf(ctx, rels(j).parent, 'copyright');
    if ~isempty(o)
        holders{end+1} = o; %#ok<AGROW>
    end
end
years = strings(1, 0);
s = statementsAbout(ctx, dsId, parts.year.ndi_target);
markStatements(ctx, s);
vals = valuesOf(s, 'date');
for j = 1:numel(vals)
    if ~isstruct(vals{j}) || ~isfield(vals{j}, 'instant')
        continue;
    end
    y = regexp(char(string(vals{j}.instant)), '^-?\d{4}', 'match', 'once');
    if isempty(y)
        note(ctx, 'Copyright', 'year', char(string(vals{j}.instant)), 'the date has no year');
    else
        years(end+1) = string(y); %#ok<AGROW>
    end
end
years = unique(years, 'stable');
if isempty(holders) && isempty(years)
    return;
end
c = openminds.core.data.Copyright();
made(ctx, 'Copyright', dsId, c);
if ~isempty(holders)
    assign(ctx, c, 'Copyright', 'holder', asValue(holders), dsId);
end
if ~isempty(years)
    assign(ctx, c, 'Copyright', 'year', years, dsId);
end
assign(ctx, dv, 'DatasetVersion', 'copyright', c, dsId);
end

function exportDocumentation(ctx, dv, dsId, row)
%EXPORTDOCUMENTATION openMINDS `documentation` ([documentation from
%   subjectOf]): the dataset's `subjectOf` document, written with that
%   document's global identifier (a DOI, an ISBN, or a URL as a
%   WebResource). openMINDS takes one; more than one is reported. With
%   none, `documentation` is in REPORT.missing.
arguments
    ctx (1,1) struct
    dv
    dsId (1,:) char
    row (1,1) struct
end
rels = relationsFrom(ctx, dsId, row.ndi_target);
endpoint = cellstr(row.endpoint);
found = {};
for j = 1:numel(rels)
    markRead(ctx, rels(j).id);
    p = docOf(ctx, rels(j).parent);
    if isempty(p)
        note(ctx, 'DatasetVersion', 'documentation', rels(j).parent, 'the document is not among the documents');
        continue;
    end
    if ~ndi.v2.vocabIs('entity_type', entityType(p), endpoint, ctx.schemaPath)
        note(ctx, 'DatasetVersion', 'documentation', rels(j).parent, sprintf(['a `subjectOf` ' ...
            'entity of type `%s`: the crosswalk takes %s'], ndi.v2.termName(entityType(p)), ...
            strjoin(endpoint, ', ')));
        continue;
    end
    [objs, texts, whys] = documentIdentifiers(p);
    if isempty(objs)
        why = 'the document has no DOI, ISBN or URL global_identifier';
        if ~isempty(whys)
            why = strjoin(whys, '; ');
        end
        note(ctx, 'DatasetVersion', 'documentation', rels(j).parent, why);
        continue;
    end
    if numel(objs) > 1
        note(ctx, 'DatasetVersion', 'documentation', rels(j).parent, sprintf(['the document ' ...
            'has %d identifiers openMINDS can take (%s); which one documents the dataset is ' ...
            'not decided'], numel(objs), strjoin(texts, ', ')));
        continue;
    end
    found{end+1} = struct('id', rels(j).parent, 'obj', objs{1}, 'text', texts{1}); %#ok<AGROW>
end
if isempty(found)
    return;
end
if numel(found) > 1
    for j = 1:numel(found)
        note(ctx, 'DatasetVersion', 'documentation', found{j}.text, sprintf(['%d `subjectOf` ' ...
            'documents: openMINDS documentation takes one, and which is not decided'], numel(found)));
    end
    return;
end
assign(ctx, dv, 'DatasetVersion', 'documentation', found{1}.obj, dsId);
end

function [objs, texts, whys] = documentIdentifiers(p)
% a document entity's identifiers that openMINDS documentation takes
arguments
    p (1,1) struct
end
[scheme, local, text] = identifiers(p);
objs = {};
texts = {};
whys = {};
for k = 1:numel(scheme)
    if ~any(strcmp(scheme{k}, {'doi', 'isbn', 'IRI'}))
        continue;
    end
    [o, why] = identifierObject(scheme{k}, local{k});
    if isempty(o)
        whys{end+1} = why; %#ok<AGROW>
        continue;
    end
    objs{end+1} = o; %#ok<AGROW>
    texts{end+1} = text{k}; %#ok<AGROW>
end
end

function exportFunding(ctx, dv, dsId, row)
%EXPORTFUNDING openMINDS Funding, one per `funding` grant: its fields from
%   the crosswalk's Funding rows, its funder from the grant's `funder`
%   relation.
arguments
    ctx (1,1) struct
    dv
    dsId (1,:) char
    row (1,1) struct
end
rels = relationsFrom(ctx, dsId, row.ndi_target);
rows = ctx.cw.types.Funding.properties;
funding = {};
for j = 1:numel(rels)
    markRead(ctx, rels(j).id);
    gid = rels(j).parent;
    p = docOf(ctx, gid);
    if isempty(p)
        note(ctx, 'DatasetVersion', 'funding', gid, 'the grant is not among the documents');
        continue;
    end
    f = openminds.core.miscellaneous.Funding();
    made(ctx, 'Funding', gid, f);
    fillFromRows(ctx, f, 'Funding', p, rows);
    if isfield(rows, 'funder') && strcmp(rows.funder.target_kind, 'relation')
        funders = relationsFrom(ctx, gid, rows.funder.ndi_target);
        if numel(funders) > 1
            note(ctx, 'Funding', 'funder', gid, sprintf(['%d funders: openMINDS Funding takes ' ...
                'one'], numel(funders)));
        elseif isscalar(funders)
            o = actorOf(ctx, funders(1).parent, 'funder', 'Funding');
            if ~isempty(o)
                assign(ctx, f, 'Funding', 'funder', o, gid);
            end
        end
    end
    funding{end+1} = f; %#ok<AGROW>
end
if ~isempty(funding)
    assign(ctx, dv, 'DatasetVersion', 'funding', [funding{:}], dsId);
end
end

function exportRelatedPublications(ctx, dv, dsId, row)
%EXPORTRELATEDPUBLICATIONS openMINDS relatedPublication: each cited
%   publication's DOI or ISBN.
arguments
    ctx (1,1) struct
    dv
    dsId (1,:) char
    row (1,1) struct
end
rels = relationsFrom(ctx, dsId, row.ndi_target);
pubs = {};
for j = 1:numel(rels)
    markRead(ctx, rels(j).id);
    p = docOf(ctx, rels(j).parent);
    if isempty(p)
        note(ctx, 'DatasetVersion', 'relatedPublication', rels(j).parent, ...
            'the publication is not among the documents');
        continue;
    end
    [scheme, local] = identifiers(p);
    got = false;
    for k = 1:numel(scheme)
        if ~any(strcmp(scheme{k}, {'doi', 'isbn'}))
            continue;
        end
        [o, why] = identifierObject(scheme{k}, local{k});
        if isempty(o)
            note(ctx, 'DatasetVersion', 'relatedPublication', rels(j).parent, why);
        else
            pubs{end+1} = o; %#ok<AGROW>
            got = true;
        end
    end
    if ~got
        note(ctx, 'DatasetVersion', 'relatedPublication', rels(j).parent, ...
            'the publication has no DOI or ISBN global_identifier');
    end
end
if ~isempty(pubs)
    assign(ctx, dv, 'DatasetVersion', 'relatedPublication', asValue(pubs), dsId);
end
end

% =============================================================================
% writing, and the report
% =============================================================================

function v = asValue(objs)
%ASVALUE A cell of openMINDS objects as one property value: the object, an
%   array of one class, or (mixed classes) the cell a mixed-type property takes.
arguments
    objs cell
end
classes = cellfun(@class, objs, 'UniformOutput', false);
if isscalar(objs)
    v = objs{1};
elseif isscalar(unique(classes))
    v = [objs{:}];
else
    v = objs;
end
end

function ok = assign(ctx, obj, typeName, prop, value, item)
%ASSIGN OBJ.(PROP) = VALUE, or a notExported row with openMINDS' reason.
arguments
    ctx (1,1) struct
    obj
    typeName (1,:) char
    prop (1,:) char
    value
    item (1,:) char
end
try
    obj.(prop) = value;
    ok = true;
catch ME
    ok = false;
    note(ctx, typeName, prop, item, sprintf('openMINDS refused the value: %s', ME.message));
end
end

function note(ctx, typeName, prop, item, why)
arguments
    ctx (1,1) struct
    typeName (1,:) char
    prop (1,:) char
    item
    why (1,:) char
end
entries = ctx.log('notExported');
entries(end+1) = struct('type', typeName, 'property', prop, 'item', char(string(item)), 'why', why);
ctx.log('notExported') = entries;
end

function made(ctx, typeName, id, obj)
arguments
    ctx (1,1) struct
    typeName (1,:) char
    id (1,:) char
    obj
end
m = ctx.log('made');
m(end+1, :) = {typeName, id, obj};
ctx.log('made') = m;
end

function rows = missingRequired(ctx)
%MISSINGREQUIRED Each made object's required openMINDS properties that have
%   no value (openMINDS_MATLAB's own `Required` list for the type).
arguments
    ctx (1,1) struct
end
rows = struct('type', {}, 'item', {}, 'property', {});
m = ctx.log('made');
for k = 1:size(m, 1)
    obj = m{k, 3};
    mc = metaclass(obj);
    pr = findobj(mc.PropertyList, 'Name', 'Required');
    if isempty(pr) || ~pr(1).HasDefault
        continue;
    end
    required = string(pr(1).DefaultValue);
    for r = reshape(required, 1, [])
        if ~hasValue(obj.(char(r)))
            rows(end+1) = struct('type', m{k, 1}, 'item', m{k, 2}, 'property', char(r)); %#ok<AGROW>
        end
    end
end
end

function tf = hasValue(v)
arguments
    v
end
if isempty(v)
    tf = false;
elseif isstring(v)
    tf = any(~ismissing(v) & strlength(v) > 0);
elseif isdatetime(v)
    tf = any(~isnat(v));
else
    tf = true;
end
end

function rows = unread(ctx, dsId)
%UNREAD The dataset's statements and relations from it that no crosswalk row read.
arguments
    ctx (1,1) struct
    dsId (1,:) char
end
rows = struct('id', {}, 'kind', {}, 'what', {});
for k = find((ctx.isStatement & strcmp(ctx.about, dsId)) | (ctx.isRelation & strcmp(ctx.child, dsId)))
    id = ctx.ids{k};
    if isKey(ctx.read, id)
        continue;
    end
    p = ctx.P{k};
    if ctx.isStatement(k)
        rows(end+1) = struct('id', id, 'kind', 'statement', 'what', ...
            ndi.v2.termName(ndi.v2.blockOf(p, 'statement', 'variable', ''))); %#ok<AGROW>
    else
        rows(end+1) = struct('id', id, 'kind', 'relation', 'what', ...
            ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', ''))); %#ok<AGROW>
    end
end
end

function s = describeRelation(ctx, rel)
arguments
    ctx (1,1) struct
    rel (1,1) struct
end
s = sprintf('%s -> %s (relation %s)', ndi.v2.termName(rel.relation), rel.parent, rel.id);
if isKey(ctx.byId, rel.parent)
    name = ndi.v2.blockOf(ctx.P{ctx.byId(rel.parent)}, 'entity', 'name', '');
    if ~isempty(name)
        s = sprintf('%s -> %s (%s; relation %s)', ndi.v2.termName(rel.relation), char(name), ...
            rel.parent, rel.id);
    end
end
end
