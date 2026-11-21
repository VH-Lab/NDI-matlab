function c = strainEntityCensus(bodies, label)
%STRAINENTITYCENSUS Per session, how many strain entities exist per strain name.
%   C = ndi.unittest.migrate.strainEntityCensus(BODIES, LABEL) reads a cell of
%   migrated (V_eta) document structs and prints, DENOMINATORS FIRST:
%     * documents inspected, entities, strain entities, sessions seen;
%     * the strain entities some `instance_of` points at (SUBJECT strains),
%       per HOME session (the strain entity's own session_id, which is the
%       dataset entity when the strain was put at the dataset level): each
%       strain name and how many strain entities carry it;
%     * the other strain entities (no `instance_of` points at them: a
%       dataset-level bacterium, or an ancestor reached by `derived_from`),
%       likewise;
%     * per SUBJECT session (the session of the `instance_of` relation): each
%       strain name and how many DISTINCT strain entities the relations point
%       at;
%     * subjects with more than one `instance_of` to a strain, and subjects
%       that are an `instance_of` more than one strain entity;
%     * `openminds:` entries in strain entities' global_identifier.
%   It asserts nothing; ndi.unittest.migrate.verifyStrainsAfterSecondPass
%   asserts on what it returns.
%
%   [openMINDS minted ids are an accepted loss] and [lab-made strain ids are
%   an accepted loss too] (Jess Haley, 2026-11-19, did-schema
%   did_v2_go_forward_class_audit.md): "Strains have one strain entity per
%   strain name per session"; "no `openminds:<id>` is written on any strain
%   entity's `global_identifier`".
if nargin < 2; label = ''; end
S = ndi.migrate.internal.etaShape;
c = struct('documents', numel(bodies), 'entities', 0, 'strain_entities', 0, ...
    'sessions', 0, 'subject_strain_entities', 0, 'other_strain_entities', 0, ...
    'subject_strain_pairs', 0, 'subject_strain_pairs_over_one', 0, ...
    'other_strain_pairs', 0, 'other_strain_pairs_over_one', 0, ...
    'instance_of_to_strain', 0, 'subjects_with_instance_of', 0, ...
    'subjects_with_two_instance_of', 0, 'subjects_with_two_strains', 0, ...
    'subject_session_pairs', 0, 'subject_session_pairs_over_one', 0, ...
    'openminds_ids_on_strains', 0);
c.subject_strain_names = {};
c.other_strain_names = {};
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
                nnz(startsWith(cellfun(@char, g, 'UniformOutput', false), ...
                'openminds:', 'IgnoreCase', true));
        end
    end
end
c.sessions = numel(unique(sessions));

% ---- instance_of relations to a strain --------------------------------------
subjStrains = containers.Map('KeyType', 'char', 'ValueType', 'any');
subjCount   = containers.Map('KeyType', 'char', 'ValueType', 'double');
pairTargets = containers.Map('KeyType', 'char', 'ValueType', 'any');
targeted    = {};
for k = 1:numel(bodies)
    s = bodies{k};
    if ~isstruct(s) || ~strcmp(S.relationName(s), 'instance_of'); continue; end
    [child, parent] = S.relationEnds(s);
    if isempty(parent) || ~isKey(strainName, parent); continue; end
    c.instance_of_to_strain = c.instance_of_to_strain + 1;
    targeted{end+1} = parent; %#ok<AGROW>
    pk = [char(ndi.v2.sessionIdOf(s)) ' | ' strainName(parent)];
    if isKey(pairTargets, pk)
        pairTargets(pk) = unique([pairTargets(pk), {parent}]);
    else
        pairTargets(pk) = {parent};
    end
    if isKey(subjStrains, child)
        subjStrains(child) = unique([subjStrains(child), {parent}]);
        subjCount(child) = subjCount(child) + 1;
    else
        subjStrains(child) = {parent};
        subjCount(child) = 1;
    end
end
targeted = unique(targeted);
c.subjects_with_instance_of = subjStrains.Count;
if subjStrains.Count > 0
    c.subjects_with_two_strains = nnz(cellfun(@numel, values(subjStrains)) > 1);
    c.subjects_with_two_instance_of = nnz(cell2mat(values(subjCount)) > 1);
end

fprintf(['\n  STRAIN ENTITY CENSUS %s\n' ...
         '    DENOMINATOR: %d document(s) inspected, %d entit(ies), %d strain ' ...
         'entit(ies), %d session id(s) seen\n'], ...
    label, c.documents, c.entities, c.strain_entities, c.sessions);

% ---- per home session x name, subject strains and the rest ------------------
ids = keys(strainName);
isSubj = ismember(ids, targeted);
c.subject_strain_entities = nnz(isSubj);
c.other_strain_entities   = nnz(~isSubj);
[c.subject_strain_pairs, c.subject_strain_pairs_over_one, c.subject_strain_names] = ...
    homePairs(ids(isSubj), 'SUBJECT strain entities (an instance_of points at them)');
[c.other_strain_pairs, c.other_strain_pairs_over_one, c.other_strain_names] = ...
    homePairs(ids(~isSubj), 'OTHER strain entities (no instance_of points at them)');

pk = keys(pairTargets);
c.subject_session_pairs = numel(pk);
fprintf(['    instance_of relations to a strain entity: %d, from %d subject(s); ' ...
         'per SUBJECT session: %d (session, name) pair(s)\n'], ...
    c.instance_of_to_strain, c.subjects_with_instance_of, c.subject_session_pairs);
for q = 1:numel(pk)
    t = pairTargets(pk{q});
    if numel(t) > 1
        c.subject_session_pairs_over_one = c.subject_session_pairs_over_one + 1;
    end
    fprintf('      %s : subjects point at %d distinct strain entit(ies)%s\n', pk{q}, ...
        numel(t), repmat('   <-- MORE THAN ONE', 1, numel(t) > 1));
end
fprintf(['    subject-session pairs pointing at more than one strain entity of one ' ...
         'name: %d; subjects with more than one instance_of to a strain: %d; subjects ' ...
         'an instance_of more than one strain entity: %d\n' ...
         '    `openminds:` entries in strain global_identifier: %d\n'], ...
    c.subject_session_pairs_over_one, c.subjects_with_two_instance_of, ...
    c.subjects_with_two_strains, c.openminds_ids_on_strains);

    function [nPairs, nOver, names] = homePairs(sel, title)
        names = {};
        if isempty(sel)
            nPairs = 0; nOver = 0;
            fprintf('    %s: none\n', title);
            return;
        end
        homeKey = cellfun(@(i) [strainHome(i) ' | ' strainName(i)], sel, ...
            'UniformOutput', false);
        [u, ~, j] = unique(homeKey);
        n = accumarray(j(:), 1);
        nPairs = numel(u);
        nOver = nnz(n > 1);
        names = unique(cellfun(@(i) strainName(i), sel, 'UniformOutput', false));
        fprintf(['    %s: %d entit(ies) in %d (home session, name) pair(s), %d with ' ...
                 'more than one strain entity; %d distinct name(s)\n'], ...
            title, numel(sel), nPairs, nOver, numel(names));
        for qq = 1:numel(u)
            fprintf('      %s : %d strain entit(ies)%s\n', u{qq}, n(qq), ...
                repmat('   <-- MORE THAN ONE', 1, n(qq) > 1));
        end
    end
end
