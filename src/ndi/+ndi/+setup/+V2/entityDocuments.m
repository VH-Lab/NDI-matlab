function docs = entityDocuments(className, fields, edges, options)
%ENTITYDOCUMENTS The documents that record one entity.
%
%   DOCS = ndi.setup.V2.entityDocuments(CLASSNAME, FIELDS, EDGES, 'SessionId', SID)
%   builds an entity given as one of the pre-2026-10-08 classes (CLASSNAME
%   'subject', 'strain', 'person', 'dataset', 'session', 'epoch', ...; FIELDS
%   and EDGES as that class declared them) and returns a cell array of
%   documents, the entity's own first. The schema has one `entity` class
%   (did-schema V_eta_entity_composition_plan.md), so DOCS is:
%     1. an `entity` with `type` CLASSNAME (for a subject, its own `type`, or the
%        'Type' option) and the identity fields -- name, local_identifier,
%        description, global_identifier (as CURIEs, ndi.setup.V2.curie) -- and
%        the time reference edge;
%     2. one assertion per other field (a term, text or date assertion whose
%        `variable` is the field's name with spaces, with its ontology node
%        where one is decided: species NCIT:C45293, accessibility
%        NCIT:C175887, a strain's genotype NCIT:C16631 as text);
%     3. one relation per other edge: vendor_id -> sold_by, background_strain_id
%        -> derived_from, product_id -> distributed_as.
%   A field or edge with no home there is an error (ndi:setup:V2:noHome), never
%   dropped.
%
%   Options: 'SessionId' (required), 'Id', 'Validate' (default true),
%   'Type' (the entity type of a subject that gives none).
%
%   See also ndi.setup.V2.curie.

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

% ---- 1. the entity ------------------------------------------------------------
type = className;
if strcmp(className, 'subject')
    if isfield(fields, 'type') && ~isempty(fields.type)
        % NDI's handle for the type, by its node when it has one
        type = ndi.v2.vocabHandle('entity_type', fields.type);
    elseif ~isempty(options.Type)
        type = options.Type;
    else
        error('ndi:setup:V2:noType', ['A subject needs a type; pass ''Type'' ' ...
            '(organism, device, ...).']);
    end
end
% the type's node and the name the schema stores for it (Jess Haley 2026-10-22
% [vocabulary nodes] L2: written with its node, matched by node)
ent = struct('type', ndi.v2.vocabTerm('entity_type', type));
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
for n = {'name', 'local_identifier', 'notes'}
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
identity = {'type', 'name', 'local_identifier', 'notes', 'global_identifier'};
% a keyword is the dataset's own free text, not a term (Jess Haley, 2026-10-21)
terms = {'species', 'genetic_strain_type', 'phenotype', 'breeding_type', 'disease_model', ...
    'license', 'accessibility', 'ethics_jurisdiction', 'experimental_approach', ...
    'factors'};
dates = {'release_date', 'publication_date'};
texts = {'short_name', 'version', 'version_innovation', 'how_to_cite', 'support_channel', ...
    'copyright_year', 'given_name', 'family_name', 'alternate_name', 'email', ...
    'catalog_number', 'lot_number', 'laboratory_code', 'synonym', 'authors', 'genotype', ...
    'keyword'};
% the variables with a decided ontology node (the Haley import's term pass,
% 2026-10-19; accessibility as did-schema's binding registry names it; the
% rest by tenet T19's node pass, 2026-10-20, Haley decision #106)
variableNodes = struct('species', 'NCIT:C45293', 'accessibility', 'NCIT:C175887', ...
    'given_name', 'IAO:0020016', 'family_name', 'IAO:0020017', 'email', 'NCIT:C42775', ...
    'catalog_number', 'NCIT:C99286', 'keyword', 'EDAM:data_0968', 'license', 'NCIT:C43611', ...
    'factors', 'OBI:0000750', 'short_name', 'NCIT:C42610', 'version', 'IAO:0000129', ...
    'authors', 'IAO:0000321', 'publication_date', 'EMPTY:0000345', ...
    'release_date', 'EMPTY:0000346', 'genetic_strain_type', 'EMPTY:0000347', ...
    'genotype', 'NCIT:C16631', ...
    'ethics_jurisdiction', 'EMPTY:0000359', 'experimental_approach', 'EMPTY:0000356');
% (ethics_jurisdiction and experimental_approach are explicit so they do not
% depend on a name lookup -- Jess Haley, 2026-10-21. ethics_jurisdiction
% replaces ethics_assessment, EMPTY:0000355, now obsolete, after openMINDS v6+
% ethicsJurisdiction; a study's `design` (OBI:0500000) is dropped, Jess Haley
% 2026-10-21, proposed, not signed: DID-schema V_eta_study_plan.md.)
names = setdiff(fieldnames(fields), identity, 'stable');
for k = 1:numel(names)
    f = names{k};
    v = fields.(f);
    if isempty(v)
        continue;
    end
    variable = strrep(f, '_', ' ');
    % the registry's spelling of the term (tenet T19): by its decided node
    % ('accessibility' is NCIT's Open or Controlled Data Access Indicator), or
    % else by the field's name
    if isfield(variableNodes, f)
        variable = ndi.setup.V2.registeredTerm(variableNodes.(f), variable);
    else
        variable = ndi.setup.V2.registeredTerm('', variable);
    end
    if strcmp(f, 'license') && (ischar(v) || (isstring(v) && isscalar(v)))
        % a licence named by its SPDX identifier ('CC-BY-4.0') is the
        % registered term spdx:<id> (Bioregistry's `spdx` prefix; no ontology
        % has licence terms; Jess Haley, 2026-10-21), its label the registry's
        v = ndi.setup.V2.registeredTerm(['spdx:' strtrim(char(v))], strtrim(char(v)));
    end
    if any(strcmp(f, terms))
        docs{end+1} = did2.build.statement('assertion', eid, variable, asTerms(v), common{:}, 'ValueKind', 'term'); %#ok<AGROW>
    elseif any(strcmp(f, dates))
        d = cellstr(v);
        docs{end+1} = did2.build.statement('assertion', eid, variable, ...
            did2.build.valueCell('date', d, 'Fields', struct('precision', precisionOf(d{1}))), ...
            common{:}, 'ValueKind', 'date'); %#ok<AGROW>
    elseif any(strcmp(f, texts))
        docs{end+1} = did2.build.statement('assertion', eid, variable, ...
            did2.build.valueCell('text', cellstr(string(v))), common{:}, 'ValueKind', 'text'); %#ok<AGROW>
    else
        error('ndi:setup:V2:noHome', ['`%s.%s` has no home on the entity: name ' ...
            'it in ndi.setup.V2.entityDocuments.'], className, f);
    end
end

% ---- 3. the other edges, as relations ---------------------------------------------
% a strain is DISTRIBUTED AS its product (a stock-centre or vendor listing), not
% derived from it (Haley import decision #17; did-schema 033a22d, 2026-10-15)
relationOf = struct('vendor_id', 'sold_by', 'background_strain_id', 'derived_from', ...
    'product_id', 'distributed_as');
enames = setdiff(fieldnames(edges), {'time_reference_id'}, 'stable');
for k = 1:numel(enames)
    e = enames{k};
    if ~isfield(relationOf, e)
        error('ndi:setup:V2:noHome', ['Edge `%s.%s` has no home on the entity: ' ...
            'name it in ndi.setup.V2.entityDocuments.'], className, e);
    end
    parents = cellstr(edges.(e));
    for j = 1:numel(parents)
        docs{end+1} = did2.build.directedRelation(eid, parents{j}, ...
            ndi.v2.vocabTerm('relation', relationOf.(e)), common{:}); %#ok<AGROW>
    end
end
end

function t = asTerms(v)
% one term, or a list of them, from terms or plain names
arguments
    v
end
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
arguments
    s {mustBeText}
end
switch numel(regexp(s, '\d+', 'match'))
    case 1, p = 'year';
    case 2, p = 'month';
    otherwise, p = 'day';
end
end
