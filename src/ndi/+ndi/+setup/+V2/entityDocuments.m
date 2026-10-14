function docs = entityDocuments(className, fields, edges, options)
%ENTITYDOCUMENTS The documents that record one entity, for the schema in use.
%
%   DOCS = ndi.setup.V2.entityDocuments(CLASSNAME, FIELDS, EDGES, 'SessionId', SID)
%   builds an entity written for the pre-2026-10-08 classes (CLASSNAME
%   'subject', 'strain', 'person', 'dataset', 'session', 'epoch', ...; FIELDS
%   and EDGES as that class declared them) and returns a cell array of
%   documents, the entity's own first.
%
%   On a schema that still has CLASSNAME, DOCS is that one document.
%
%   On a schema with one `entity` class (did-schema
%   V_eta_entity_composition_plan.md, 2026-10-08), DOCS is:
%     1. an `entity` with `type` CLASSNAME (for a subject, its own `type`, or the
%        'Type' option) and the identity fields -- name, local_identifier,
%        description, global_identifier (as CURIEs, ndi.setup.V2.curie) -- and
%        the time reference edge;
%     2. one assertion per other field (a term, text or date assertion whose
%        `variable` is the field's name with spaces);
%     3. one relation per other edge: vendor_id -> sold_by, background_strain_id
%        and product_id -> derived_from.
%   A field or edge with no home there is an error (ndi:setup:V2:noHome), never
%   dropped.
%
%   Options: 'SessionId' (required), 'Id', 'Validate' (default true),
%   'Type' (the entity type of a subject that gives none).
%
%   See also ndi.setup.V2.mergedEntities, ndi.setup.V2.curie.

arguments
    className (1,:) char
    fields (1,1) struct
    edges (1,1) struct = struct()
    options.SessionId (1,:) char
    options.Id (1,:) char = ''
    options.Validate (1,1) logical = true
    options.Type (1,:) char = ''
end

common = {'SessionId', options.SessionId, 'Validate', options.Validate};
if ~ndi.setup.V2.mergedEntities()
    docs = {did2.build.document(className, fields, 'Edges', edges, ...
        'Id', options.Id, common{:})};
    return;
end

% ---- 1. the entity ------------------------------------------------------------
type = className;
if strcmp(className, 'subject')
    if isfield(fields, 'type') && ~isempty(fields.type)
        type = termName(fields.type);
    elseif ~isempty(options.Type)
        type = options.Type;
    else
        error('ndi:setup:V2:noType', ['A subject needs a type on a schema with ' ...
            'one entity class; pass ''Type'' (organism, device, ...).']);
    end
end
ent = struct('type', did2.build.term('', type));
if strcmp(className, 'person') && ~isfield(fields, 'name')
    % the type registry asks a person for a display name; the spec gives parts
    parts = {};
    for n = {'given_name', 'family_name'}
        if isfield(fields, n{1}) && ~isempty(fields.(n{1}))
            parts{end+1} = char(fields.(n{1})); %#ok<AGROW>
        end
    end
    if ~isempty(parts)
        fields.name = strjoin(parts, ' ');
    end
end
for n = {'name', 'local_identifier', 'description'}
    if isfield(fields, n{1}) && ~isempty(fields.(n{1}))
        ent.(n{1}) = fields.(n{1});
    end
end
if isfield(fields, 'global_identifier') && ~isempty(fields.global_identifier)
    [ids, award] = ndi.setup.V2.curie(fields.global_identifier);
    if ~isempty(ids)
        ent.global_identifier = ids;
    end
    if ~isempty(award) && ~isfield(ent, 'local_identifier')
        ent.local_identifier = award;
    end
end
entEdges = struct();
if isfield(edges, 'time_reference_id')
    entEdges.time_reference_id = edges.time_reference_id;
end
docs = {did2.build.document('entity', ent, 'Edges', entEdges, 'Id', options.Id, common{:})};
eid = docs{1}.base.id;

% ---- 2. the other fields, as assertions ------------------------------------------
identity = {'type', 'name', 'local_identifier', 'description', 'global_identifier'};
terms = {'species', 'genetic_strain_type', 'phenotype', 'breeding_type', 'disease_model', ...
    'keyword', 'license', 'accessibility', 'ethics_assessment', 'experimental_approach', ...
    'factors', 'design'};
dates = {'release_date', 'publication_date'};
texts = {'short_name', 'version', 'version_innovation', 'how_to_cite', 'support_channel', ...
    'copyright_year', 'given_name', 'family_name', 'alternate_name', 'email', ...
    'catalog_number', 'lot_number', 'laboratory_code', 'synonym', 'authors'};
names = setdiff(fieldnames(fields), identity, 'stable');
for k = 1:numel(names)
    f = names{k};
    v = fields.(f);
    if isempty(v)
        continue;
    end
    variable = strrep(f, '_', ' ');
    if any(strcmp(f, terms))
        docs{end+1} = did2.build.statement('term_assertion', eid, variable, asTerms(v), common{:}); %#ok<AGROW>
    elseif any(strcmp(f, dates))
        d = cellstr(v);
        docs{end+1} = did2.build.statement('date_assertion', eid, variable, ...
            did2.build.valueCell('date', d, 'Fields', struct('precision', precisionOf(d{1}))), ...
            common{:}); %#ok<AGROW>
    elseif any(strcmp(f, texts))
        docs{end+1} = did2.build.statement('text_assertion', eid, variable, ...
            did2.build.valueCell('text', cellstr(string(v))), common{:}); %#ok<AGROW>
    else
        error('ndi:setup:V2:noHome', ['`%s.%s` has no home on a schema with one ' ...
            'entity class: name it in ndi.setup.V2.entityDocuments.'], className, f);
    end
end

% ---- 3. the other edges, as relations ---------------------------------------------
relationOf = struct('vendor_id', 'sold_by', 'background_strain_id', 'derived_from', ...
    'product_id', 'derived_from');
enames = setdiff(fieldnames(edges), {'time_reference_id'}, 'stable');
for k = 1:numel(enames)
    e = enames{k};
    if ~isfield(relationOf, e)
        error('ndi:setup:V2:noHome', ['Edge `%s.%s` has no home on a schema with ' ...
            'one entity class: name it in ndi.setup.V2.entityDocuments.'], className, e);
    end
    parents = cellstr(edges.(e));
    for j = 1:numel(parents)
        docs{end+1} = did2.build.directedRelation(eid, parents{j}, ...
            did2.build.term('', relationOf.(e)), common{:}); %#ok<AGROW>
    end
end
end

function n = termName(t)
if isstruct(t)
    n = char(t.name);
else
    n = char(t);
end
end

function t = asTerms(v)
% one term, or a list of them, from terms or plain names
if isstruct(v)
    t = v;
    return;
end
c = cellstr(string(v));
t = did2.build.label(c{1});
for k = 2:numel(c)
    t(k) = did2.build.label(c{k});
end
end

function p = precisionOf(s)
% a partial-precision date: YYYY, YYYY-MM or YYYY-MM-DD
switch numel(regexp(s, '\d+', 'match'))
    case 1, p = 'year';
    case 2, p = 'month';
    otherwise, p = 'day';
end
end
