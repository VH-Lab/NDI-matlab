function c = strainEntityCensus(bodies)
%STRAINENTITYCENSUS Per session, how many strain entities exist per strain name.
%   C = ndi.unittest.migrate.strainEntityCensus(BODIES) reads a cell of migrated
%   (V_eta) document structs and prints, DENOMINATORS FIRST:
%     * documents inspected, entities, strain entities, sessions seen;
%     * per HOME session (the strain entity's own session_id, which is the
%       dataset entity when the strain was put at the dataset level): each
%       strain name and how many strain entities carry it;
%     * per SUBJECT session (the session of the document an `instance_of`
%       relation to a strain starts from): each strain name and how many
%       DISTINCT strain entities those relations point at;
%     * subjects that are an `instance_of` more than one strain entity;
%     * `openminds:` entries in strain entities' global_identifier.
%   Measurement only (MEASURE before changing the strain assembly); it asserts
%   nothing.
S = ndi.migrate.internal.etaShape;
c = struct('documents', numel(bodies), 'entities', 0, 'strain_entities', 0, ...
    'sessions', 0, 'home_pairs', 0, 'home_pairs_over_one', 0, ...
    'instance_of_to_strain', 0, 'subject_pairs', 0, 'subject_pairs_over_one', 0, ...
    'subjects_with_two_strains', 0, 'openminds_ids_on_strains', 0);
strainName = containers.Map('KeyType', 'char', 'ValueType', 'char');
strainHome = containers.Map('KeyType', 'char', 'ValueType', 'char');
sessions = {};
for k = 1:numel(bodies)
    s = bodies{k};
    if ~isstruct(s); continue; end
    sid = ndi.v2.sessionIdOf(s);
    if ~isempty(sid); sessions{end+1} = char(sid); end %#ok<AGROW>
    if ~S.isEntity(s); continue; end
    c.entities = c.entities + 1;
    if ~strcmp(S.entityType(s), 'strain'); continue; end
    c.strain_entities = c.strain_entities + 1;
    nm = '';
    if isfield(s.entity, 'name'); nm = char(s.entity.name); end
    strainName(char(s.base.id)) = nm;
    strainHome(char(s.base.id)) = char(sid);
    if isfield(s.entity, 'global_identifier')
        g = s.entity.global_identifier;
        if ischar(g); g = {g}; end
        if isstring(g); g = cellstr(g); end
        if iscell(g)
            c.openminds_ids_on_strains = c.openminds_ids_on_strains + ...
                nnz(startsWith(cellfun(@char, g, 'UniformOutput', false), 'openminds:'));
        end
    end
end
c.sessions = numel(unique(sessions));
fprintf(['\n  STRAIN ENTITY CENSUS\n' ...
         '    DENOMINATOR: %d document(s) inspected, %d entit(ies), %d strain ' ...
         'entit(ies), %d session id(s) seen\n'], ...
    c.documents, c.entities, c.strain_entities, c.sessions);

% per home session x name
ids = keys(strainName);
homeKey = cellfun(@(i) [strainHome(i) ' | ' strainName(i)], ids, 'UniformOutput', false);
[u, ~, j] = unique(homeKey);
n = accumarray(j(:), 1);
c.home_pairs = numel(u);
c.home_pairs_over_one = nnz(n > 1);
fprintf('    per HOME session: %d (session, name) pair(s), %d with more than one strain entity\n', ...
    c.home_pairs, c.home_pairs_over_one);
for q = 1:numel(u)
    fprintf('      %s : %d strain entit(ies)%s\n', u{q}, n(q), ...
        repmat('   <-- MORE THAN ONE', 1, n(q) > 1));
end

% instance_of to a strain, per subject session x name
subjStrains = containers.Map('KeyType', 'char', 'ValueType', 'any');
pairTargets = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    s = bodies{k};
    if ~isstruct(s) || ~strcmp(S.relationName(s), 'instance_of'); continue; end
    [child, parent] = S.relationEnds(s);
    if isempty(parent) || ~isKey(strainName, parent); continue; end
    c.instance_of_to_strain = c.instance_of_to_strain + 1;
    pk = [char(ndi.v2.sessionIdOf(s)) ' | ' strainName(parent)];
    if isKey(pairTargets, pk)
        pairTargets(pk) = unique([pairTargets(pk), {parent}]);
    else
        pairTargets(pk) = {parent};
    end
    if isKey(subjStrains, child)
        subjStrains(child) = unique([subjStrains(child), {parent}]);
    else
        subjStrains(child) = {parent};
    end
end
pk = keys(pairTargets);
c.subject_pairs = numel(pk);
fprintf(['    instance_of relations to a strain entity: %d, from %d subject(s); ' ...
         'per SUBJECT session: %d (session, name) pair(s)\n'], ...
    c.instance_of_to_strain, subjStrains.Count, c.subject_pairs);
for q = 1:numel(pk)
    t = pairTargets(pk{q});
    if numel(t) > 1; c.subject_pairs_over_one = c.subject_pairs_over_one + 1; end
    fprintf('      %s : subjects point at %d distinct strain entit(ies)%s\n', pk{q}, ...
        numel(t), repmat('   <-- MORE THAN ONE', 1, numel(t) > 1));
end
v = values(subjStrains);
c.subjects_with_two_strains = nnz(cellfun(@numel, v) > 1);
fprintf(['    subject pairs pointing at more than one strain entity of one name: %d; ' ...
         'subjects an instance_of more than one strain entity: %d\n' ...
         '    `openminds:` entries in strain global_identifier: %d\n'], ...
    c.subject_pairs_over_one, c.subjects_with_two_strains, c.openminds_ids_on_strains);
end
