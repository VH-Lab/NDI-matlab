function report = sameAsMatches(incoming, existing)
%SAMEASMATCHES The entities of a joining session that record what a dataset already records.
%
%   REPORT = ndi.v2.sameAsMatches(INCOMING, EXISTING) compares the entity
%   documents INCOMING can find (a session joining a dataset: an ndi.session,
%   or anything with database_search) with those EXISTING can find (the
%   dataset), one pair at a time, by V_eta tenet T18 (did-schema
%   V_eta_duplicate_entities_plan.md, signed 2026-10-19). Nothing is written.
%
%   A MATCH is evidence that names the thing itself:
%     identifier  the same identifier CURIE (wormbase:WBStrain00000001,
%                 orcid:..., rrid:...) on two entities of the same type
%     serial      the same serial number and the same manufacturer on two
%                 devices (assertions whose variable is `serial number` and
%                 `manufacturer`)
%     catalog     the same catalog or model number on two products
%                 (product.catalog_number, or a `catalog number` or
%                 `model number` assertion)
%   A CANDIDATE is weaker evidence, listed for a person to confirm and never
%   written: the same name on two entities of one type (two entities called
%   "N2" with no identifier may be two stocks), or the same serial number on
%   two devices whose manufacturer is not recorded on both. Two entities
%   whose identifiers (or serial, or catalog numbers) differ are two things
%   and are neither. Never evidence: a shared kind (two devices of one
%   model; two worms of one strain): those are each `instance_of` the kind.
%
%   Sessions, epochs and datasets are not compared, and a document with the
%   same id on both sides is one document, not two records.
%
%   REPORT has fields:
%     denominator  a line: how many entities were compared on each side
%     matches      table: incoming_id, existing_id, type, evidence
%     candidates   table: incoming_id, existing_id, type, name, why
%
%   See also ndi.v2.sameAs, ndi.dataset/add_linked_session.

arguments
    incoming
    existing
end

A = entitiesOf(incoming);
B = entitiesOf(existing);
report.denominator = sprintf(['DENOMINATOR: %d entity document(s) of the joining ' ...
    'session compared with %d of the dataset (sessions, epochs and datasets left out)'], ...
    numel(A), numel(B));
report.matches = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'incoming_id', 'existing_id', 'type', 'evidence'});
report.candidates = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    strings(0, 1), 'VariableNames', {'incoming_id', 'existing_id', 'type', 'name', 'why'});
bTypes = {B.type};
for a = 1:numel(A)
    for b = reshape(find(strcmp(bTypes, A(a).type)), 1, [])   % two of one type only
        x = A(a); y = B(b);
        if strcmp(x.id, y.id), continue; end
        [evidence, conflict, maybe] = compare(x, y);
        if ~isempty(evidence)
            report.matches(end+1, :) = {string(x.id), string(y.id), string(x.type), ...
                string(evidence)};
        elseif ~isempty(maybe)
            report.candidates(end+1, :) = {string(x.id), string(y.id), string(x.type), ...
                string(x.name), string(maybe)};
        elseif ~conflict && ~isempty(x.name) && strcmpi(x.name, y.name)
            report.candidates(end+1, :) = {string(x.id), string(y.id), string(x.type), ...
                string(x.name), "the same name alone"};
        end
    end
end
end

% -----------------------------------------------------------------------------
function [evidence, conflict, maybe] = compare(x, y)
% EVIDENCE: what names one thing ('' none); CONFLICT: something that names
% each of them differs, so they are two things; MAYBE: weaker evidence to list
arguments
    x (1,1) struct
    y (1,1) struct
end
evidence = ''; maybe = ''; conflict = false;
shared = intersect(x.identifiers, y.identifiers);
if ~isempty(shared)
    evidence = ['identifier ' shared{1}];
    return;
end
if ~isempty(x.identifiers) && ~isempty(y.identifiers)
    conflict = true;
end
if strcmp(x.type, 'device') && ~isempty(x.serial) && ~isempty(y.serial)
    if ~any(ismember(x.serial, y.serial))
        conflict = true;
    elseif ~isempty(x.manufacturer) && ~isempty(y.manufacturer)
        if any(ismember(x.manufacturer, y.manufacturer))
            s = x.serial(ismember(x.serial, y.serial));
            evidence = sprintf('serial number %s (manufacturer %s)', s{1}, x.manufacturer{1});
            return;
        end
        conflict = true;
    else
        maybe = 'the same serial number; the manufacturer is not recorded on both';
    end
end
if strcmp(x.type, 'product') && ~isempty(x.catalog) && ~isempty(y.catalog)
    c = x.catalog(ismember(x.catalog, y.catalog));
    if ~isempty(c)
        evidence = ['catalog or model number ' c{1}];
        return;
    end
    conflict = true;
end
if conflict, maybe = ''; end
end

function E = entitiesOf(source)
% one struct per entity document SOURCE finds: id, type, name, identifiers
% (normalised CURIEs), serial, manufacturer, catalog (lower-case cellstrs)
arguments
    source
end
E = struct('id', {}, 'type', {}, 'name', {}, 'identifiers', {}, 'serial', {}, ...
    'manufacturer', {}, 'catalog', {});
docs = source.database_search(ndi.query('', 'isa', 'entity', ''));
at = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = 1:numel(docs)
    p = ndi.v2.props(docs{i});
    t = typeOf(p);
    if isempty(t) || any(strcmp(t, {'session', 'epoch', 'dataset'})), continue; end
    id = char(p.base.id);
    if isKey(at, id), continue; end
    [~, blk] = ndi.v2.kindOf(p);
    name = strtrim(char(ndi.v2.blockOf(p, blk, 'name', '')));
    if isempty(name) && strcmp(t, 'person')
        name = strtrim([char(ndi.v2.blockOf(p, blk, 'given_name', '')) ' ' ...
            char(ndi.v2.blockOf(p, blk, 'family_name', ''))]);
    end
    if isempty(name)
        name = strtrim(char(ndi.v2.blockOf(p, blk, 'local_identifier', '')));
    end
    catalog = {};
    c = strtrim(char(ndi.v2.blockOf(p, blk, 'catalog_number', '')));
    if ~isempty(c), catalog = {lower(c)}; end
    E(end+1) = struct('id', id, 'type', t, 'name', name, 'identifiers', {identifiersOf(p)}, ...
        'serial', {{}}, 'manufacturer', {{}}, 'catalog', {catalog}); %#ok<AGROW>
    at(id) = numel(E);
end
if isempty(E), return; end
% what names a device or a product, stated as an assertion about it
fieldOf = struct('serial_number', 'serial', 'manufacturer', 'manufacturer', ...
    'catalog_number', 'catalog', 'model_number', 'catalog');
q = ndi.v2.isaQuery('assertion') & ndi.v2.termQuery('statement.variable', ...
    {'serial number', 'manufacturer', 'catalog number', 'model number'});
docs = source.database_search(q);
for i = 1:numel(docs)
    p = ndi.v2.props(docs{i});
    sid = ndi.v2.edgeIds(p, 'entity_id');
    if isempty(sid) || ~isKey(at, sid{1}), continue; end
    v = lower(strrep(strtrim(ndi.v2.termName(ndi.v2.blockOf(p, 'statement', 'variable', ''))), ' ', '_'));
    if ~isfield(fieldOf, v), continue; end
    [~, ~, txt] = ndi.v2.statementValue(p);
    if iscell(txt), txt = strjoin(cellfun(@(x) char(string(x)), txt, 'UniformOutput', false), ' '); end
    txt = lower(strtrim(char(string(txt))));
    if isempty(txt), continue; end
    k = at(sid{1});
    f = fieldOf.(v);
    E(k).(f) = unique([E(k).(f), {txt}], 'stable');
end
end

function t = typeOf(p)
% the entity's type: a merged entity's `type`, else its class; a subject's
% coarse kind (device, organism, ...) when it states one
arguments
    p
end
t = ndi.v2.kindOf(p);
if strcmp(t, 'subject')
    k = ndi.v2.vocabHandle('entity_type', ndi.v2.blockOf(p, 'subject', 'type', ''));
    if ~isempty(k), t = char(k); end
end
end

function ids = identifiersOf(p)
% the entity's global identifiers as CURIEs, the prefix lower-cased (a
% prefix is matched ignoring case); an IRI as it is
arguments
    p
end
ids = {};
g = ndi.v2.blockOf(p, 'entity', 'global_identifier', []);
if ischar(g) || isstring(g), g = cellstr(g); end
if isempty(g), return; end
if ~iscell(g) || ~all(cellfun(@ischar, g)), g = ndi.v2.entries(g); end
for i = 1:numel(g)
    sc = ''; v = '';
    if ischar(g{i})
        tok = regexp(strtrim(g{i}), '^([A-Za-z][A-Za-z0-9_.]*):(?!//)(.*)$', 'tokens', 'once');
        if isempty(tok), v = strtrim(g{i}); else, sc = tok{1}; v = tok{2}; end
    elseif isstruct(g{i})
        if isfield(g{i}, 'scheme'), sc = ndi.v2.termName(g{i}.scheme); end
        if isfield(g{i}, 'value'), v = char(g{i}.value); end
    end
    v = strtrim(v);
    if isempty(v), continue; end
    if isempty(sc)
        ids{end+1} = v; %#ok<AGROW>
    else
        ids{end+1} = [lower(char(sc)) ':' v]; %#ok<AGROW>
    end
end
ids = unique(ids, 'stable');
end
