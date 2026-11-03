function d = openMINDSobj2V2(openmindsObj, session, subjectId, varargin)
% OPENMINDSOBJ2V2 - openMINDS objects about a subject as v2 documents
%
% D = ndi.database.fun.openMINDSobj2V2(OPENMINDS_OBJ, SESSION, SUBJECT_ID)
%
% The v2 counterpart of ndi.database.fun.openMINDSobj2ndi_document(OBJ,
% SESSION, 'subject', SUBJECT_ID), for a SESSION whose database is v2
% (ndi.session/writesV2). D is a cell array of ndi.document objects built
% with did2.build in the shape the migration gives the v1 documents
% openMINDSobj2ndi_document writes:
%
%   Species                   an `assertion` (value kind `term`) about the
%                             subject: variable Species (NCIT:C45293), value
%                             the species' term
%   BiologicalSex             an `assertion` about the subject: variable
%                             biological sex (PATO:0000047), value the term
%   Strain                    an `entity` of type strain (its `name`, its
%                             description as `notes`, its identifiers as
%                             `global_identifier`), the assertions about the
%                             strain (species, genetic strain type, phenotype,
%                             breeding, disease model, laboratory code,
%                             synonym), a `derived_from` relation to each
%                             background strain (built the same way), and
%                             the subject `instance_of` the strain
%   any other controlled term an `assertion` about the subject whose variable
%                             is the openMINDS type's name ('GeneticStrainType'
%                             -> genetic strain type)
%
% That is the shape of DID-matlab's +migrators_j/openminds_subject.m (one
% term assertion per openMINDS object about the subject) after NDI's second
% pass ndi.migrate.internal.subjectStrainAssembly (a Strain becomes a strain
% entity the subject is `instance_of`, did-schema
% did_v2_entity_composition_plan.md sec. 4-5), with the variables
% ndi.setup.V2.entityDocuments writes for the same fields.
%
% Every term is written as DID-schema's term registry holds it
% (ndi.setup.V2.registeredTerm); did2.build refuses a term the registry does
% not hold (tenet T19), so a species or sex that is not registered is an
% error here, not a silent v1 write. A field of a Strain this function has no
% home for is an error (ndi:database:fun:openMINDSobj2V2:noHome), never
% dropped.
%
% Options:
%   'Strains'  a containers.Map (a handle) from a strain's content to the id
%              of the strain entity already written for it. Pass the same map
%              to every call of one import so a strain shared by many subjects
%              is written once (the migration's dedup: only an exact match of
%              content merges). Default: a new map (no dedup across calls).
%
% Decided by Jess Haley, 2026-11-03 [writers are given the session] and
% [v2 line reads and writes both] (did-schema
% did_v2_go_forward_class_audit.md): a tool learns the version from the
% session's database.
%
% See also ndi.database.fun.openMINDSobj2ndi_document, ndi.session/writesV2.

    % (no arguments block: this function has nested functions)
    if ~isa(session, 'ndi.session') || ~isscalar(session)
        error('ndi:database:fun:openMINDSobj2V2:notASession', 'SESSION must be one ndi.session.');
    end
    subjectId = char(subjectId);
    if isempty(subjectId)
        error('ndi:database:fun:openMINDSobj2V2:noSubject', 'SUBJECT_ID must not be empty.');
    end
    ip = inputParser;
    ip.addParameter('Strains', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
        @(x) isa(x, 'containers.Map'));
    ip.parse(varargin{:});
    options = ip.Results;

    if ~iscell(openmindsObj)
        asCell = cell(1, numel(openmindsObj));
        for i = 1:numel(openmindsObj)
            asCell{i} = openmindsObj(i);
        end
        openmindsObj = asCell;
    end
    sid = session.id();
    common = {'SessionId', sid};

    s = ndi.database.fun.openMINDSobj2struct(openmindsObj);
    byNdiId = containers.Map('KeyType', 'char', 'ValueType', 'double');
    byOmId = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for k = 1:numel(s)
        byNdiId(s(k).ndi_id) = k;
        byOmId(s(k).openminds_id) = k;
    end

    strainIds = containers.Map('KeyType', 'char', 'ValueType', 'char'); % ndi_id -> entity id
    strainKeys = containers.Map('KeyType', 'char', 'ValueType', 'char'); % ndi_id -> content key
    docs = {};

    % the objects given are about the subject; their children are about them
    for i = 1:numel(openmindsObj)
        omId = char(openmindsObj{i}.id);
        if ~isKey(byOmId, omId)
            error('ndi:database:fun:openMINDSobj2V2:notConverted', ...
                'openMINDS object %d was not converted (openMINDSobj2struct).', i);
        end
        k = byOmId(omId);
        switch lower(typeSuffix(s(k).openminds_type))
            case 'strain'
                strainEid = strainEntity(k);
                docs{end+1} = did2.build.directedRelation(subjectId, strainEid, ...
                    ndi.v2.vocabTerm('relation', 'instance_of'), common{:}); %#ok<AGROW>
            otherwise
                docs{end+1} = did2.build.statement('assertion', subjectId, ...
                    variableFor(s(k).openminds_type), termOf(s(k)), common{:}, ...
                    'ValueKind', 'term'); %#ok<AGROW>
        end
    end

    d = cellfun(@(x) ndi.document(x), docs, 'UniformOutput', false);

    % ------------------------------------------------------------------
    function eid = strainEntity(k)
        % the strain entity for s(k), written once per content (and per call)
        nid = s(k).ndi_id;
        if isKey(strainIds, nid)
            eid = strainIds(nid);
            return;
        end
        f = s(k).fields;
        if ~isstruct(f), f = struct(); end
        % the openMINDS Strain properties with no home here yet (the
        % migration's strainLeftovers resolves a stock number across
        % documents); every other property is written below
        noHomeYet = {'stockNumber'};
        for j = 1:numel(noHomeYet)
            if isfield(f, noHomeYet{j}) && ~isEmptyValue(f.(noHomeYet{j}))
                error('ndi:database:fun:openMINDSobj2V2:noHome', ...
                    ['Strain field `%s` has no home on the v2 strain entity: name it in ' ...
                    'ndi.database.fun.openMINDSobj2V2.'], noHomeYet{j});
            end
        end
        name = textOf(getOr(f, 'name'));
        if isempty(name)
            error('ndi:database:fun:openMINDSobj2V2:noName', ...
                'A strain needs a name (did-schema entity_type_bindings: strain requires `name`).');
        end
        parents = {};
        bg = refs(getOr(f, 'backgroundStrain'));
        for j = 1:numel(bg)
            parents{end+1} = strainEntity(bg{j}); %#ok<AGROW>
        end
        parentKeys = cellfun(@(p) strainKeys(s(p).ndi_id), bg, 'UniformOutput', false);
        ent = struct('type', ndi.v2.vocabTerm('entity_type', 'strain'), 'name', name);
        notes = textOf(getOr(f, 'description'));
        if ~isempty(notes), ent.notes = notes; end
        gid = {};
        for nm = {'ontologyIdentifier', 'digitalIdentifier', 'alternateIdentifier'}
            v = getOr(f, nm{1});
            if iscell(v) && ~isempty(v) && all(cellfun(@(x) ischar(x) && startsWith(x, 'ndi://'), v))
                error('ndi:database:fun:openMINDSobj2V2:noHome', ...
                    ['Strain field `%s` is an openMINDS object; its identifier has no home ' ...
                    'here yet: name it in ndi.database.fun.openMINDSobj2V2.'], nm{1});
            end
            for e = asTextList(v)
                g = ndi.migrate.internal.etaShape.curie(e{1});
                if ~any(strcmp(gid, g)), gid{end+1} = g; end %#ok<AGROW>
            end
        end
        if ~isempty(gid), ent.global_identifier = gid; end

        stmts = cell(0, 3);   % {variable, value, kind}
        sp = refs(getOr(f, 'species'));
        for j = 1:numel(sp)
            stmts(end+1, :) = {ndi.setup.V2.registeredTerm('NCIT:C45293', 'species'), termOf(s(sp{j})), 'term'}; %#ok<AGROW>
        end
        stmts = [stmts; childTerms('geneticStrainType', 'EMPTY:0000347', 'genetic strain type')];
        stmts = [stmts; childTerms('phenotype', '', 'phenotype')];
        stmts = [stmts; childTerms('breedingType', 'NCIT:C42877', 'breeding')];
        stmts = [stmts; childTerms('diseaseModel', 'BAO:0010279', 'disease model')];
        for nm = {{'laboratoryCode', 'laboratory code'}, {'synonym', 'synonym'}}
            t = asTextList(getOr(f, nm{1}{1}));
            if ~isempty(t)
                stmts(end+1, :) = {ndi.setup.V2.registeredTerm('', nm{1}{2}), ...
                    did2.build.valueCell('text', t), 'text'}; %#ok<AGROW>
            end
        end

        key = jsonencode(struct('ent', ent, 'stmts', {cellfun(@keyText, stmts, 'UniformOutput', false)}, ...
            'parents', {parentKeys}));
        strainKeys(nid) = key;
        if isKey(options.Strains, key)
            eid = options.Strains(key);
            strainIds(nid) = eid;
            return;
        end
        e = did2.build.document('entity', ent, common{:});
        eid = e.base.id;
        docs{end+1} = e;
        for j = 1:size(stmts, 1)
            docs{end+1} = did2.build.statement('assertion', eid, stmts{j, 1}, stmts{j, 2}, ...
                common{:}, 'ValueKind', stmts{j, 3}); %#ok<AGROW>
        end
        for j = 1:numel(parents)
            docs{end+1} = did2.build.directedRelation(eid, parents{j}, ...
                ndi.v2.vocabTerm('relation', 'derived_from'), common{:}); %#ok<AGROW>
        end
        options.Strains(key) = eid;
        strainIds(nid) = eid;

        function rows = childTerms(field, node, label)
            rows = cell(0, 3);
            kids = refs(getOr(f, field));
            if isempty(kids)
                t = asTextList(getOr(f, field));   % a term given by name
                for jj = 1:numel(t)
                    rows(end+1, :) = {ndi.setup.V2.registeredTerm(node, label), ...
                        ndi.setup.V2.registeredTerm('', t{jj}), 'term'}; %#ok<AGROW>
                end
                return;
            end
            for jj = 1:numel(kids)
                rows(end+1, :) = {ndi.setup.V2.registeredTerm(node, label), termOf(s(kids{jj})), 'term'}; %#ok<AGROW>
            end
        end
    end

    function idx = refs(v)
        % the s() indices an `ndi://` field names
        idx = {};
        if ~iscell(v), return; end
        for j = 1:numel(v)
            if ischar(v{j}) && startsWith(v{j}, 'ndi://') && isKey(byNdiId, v{j}(7:end))
                idx{end+1} = byNdiId(v{j}(7:end)); %#ok<AGROW>
            end
        end
    end
end

% ===================== local helpers ===================================

function t = termOf(sk)
% the registry's term for a controlled-term openMINDS struct
f = sk.fields;
if ~isstruct(f), f = struct(); end
node = '';
for nm = {'preferredOntologyIdentifier', 'ontologyIdentifier', 'interlexIdentifier'}
    v = textOf(getOr(f, nm{1}));
    if ~isempty(v), node = oboCurie(v); break; end
end
name = textOf(getOr(f, 'name'));
if isempty(node) && isempty(name)
    error('ndi:database:fun:openMINDSobj2V2:noTerm', ...
        'An openMINDS %s has neither an ontology identifier nor a name.', typeSuffix(sk.openminds_type));
end
t = ndi.setup.V2.registeredTerm(node, name);
end

function v = variableFor(omType)
% the variable an openMINDS type names (the migrator's variableForType)
switch lower(typeSuffix(omType))
    case 'species'
        v = ndi.setup.V2.registeredTerm('NCIT:C45293', 'species');
    case {'biologicalsex', 'sex'}
        v = ndi.setup.V2.registeredTerm('PATO:0000047', 'biological sex');
    case 'geneticstraintype'
        v = ndi.setup.V2.registeredTerm('EMPTY:0000347', 'genetic strain type');
    otherwise
        v = ndi.setup.V2.registeredTerm('', ...
            lower(strtrim(regexprep(typeSuffix(omType), '([a-z0-9])([A-Z])', '$1 $2'))));
end
end

function c = oboCurie(v)
% an OBO PURL (http://purl.obolibrary.org/obo/PATO_0001340) as its CURIE
c = v;
tok = regexp(v, '^https?://purl\.obolibrary\.org/obo/([A-Za-z]+)_(\w+)$', 'tokens', 'once');
if ~isempty(tok)
    c = [tok{1} ':' tok{2}];
end
end

function s = typeSuffix(omType)
s = char(omType);
parts = strsplit(s, {'/', '#', ':'});
parts = parts(~cellfun('isempty', parts));
if ~isempty(parts), s = parts{end}; end
end

function v = getOr(f, name)
v = [];
if isstruct(f) && isfield(f, name)
    v = f.(name);
end
end

function t = textOf(v)
t = '';
if isstring(v), v = char(strjoin(v, ' ')); end
if iscell(v) && numel(v) == 1, v = v{1}; end
v = flatChar(v);
if ischar(v), t = strtrim(v); end
end

function x = flatChar(x)
% text as a row of characters; an empty value of any shape (openMINDS
% gives an unset text property as an empty array that need not be 2-D) is ''
if isstring(x)
    x = char(strjoin(x, ' '));
end
if ischar(x)
    if isempty(x)
        x = '';
    elseif ~isrow(x)
        x = reshape(x, 1, []);
    end
end
end

function c = asTextList(v)
% non-empty texts that are not `ndi://` references
c = {};
if isstring(v), v = cellstr(v); end
if ischar(v), v = {v}; end
if ~iscell(v), return; end
for j = 1:numel(v)
    x = flatChar(v{j});
    if ischar(x) && ~isempty(strtrim(x)) && ~startsWith(x, 'ndi://')
        c{end+1} = strtrim(x); %#ok<AGROW>
    end
end
end

function tf = isEmptyValue(v)
tf = isempty(v) || (isstring(v) && all(strlength(v) == 0)) ...
    || (iscell(v) && all(cellfun(@isEmptyValue, v)));
end

function k = keyText(x)
if isstruct(x) || iscell(x)
    k = jsonencode(x);
else
    k = char(string(x));
end
end
