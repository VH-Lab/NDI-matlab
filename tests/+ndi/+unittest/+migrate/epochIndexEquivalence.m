function R = epochIndexEquivalence(migratedNdiDir, label)
%EPOCHINDEXEQUIVALENCE The derived epoch-table index against a fresh computation, after changes of every kind.
%
%   R = ndi.unittest.migrate.epochIndexEquivalence(MIGRATEDNDIDIR, LABEL)
%   copies the migrated .ndi folder, and for every session and every
%   acquisition system in it compares, epoch by epoch,
%
%     the navigator's entries   ndi.vintage.ingestedEpochs (index) against
%                               ndi.vintage.ingestedEpochs(..., 'UseIndex', false)
%     the reader's clocks       ndi.vintage.ingestedArchives(..., 'ClocksOnly', true)
%                               against the same with 'UseIndex', false
%
%   first as the database holds the index, then after REMOVING and again
%   after RE-ADDING one document of every kind the rows are read from (Jess
%   Haley, 2026-11-09, [2 a]): a manifest, its epoch entity, an anchor onto
%   it, a statement it times, a wiring relation it times, a body a statement
%   owns, the probe (element entity), the subject entity, an assertion about
%   the probe, the system, its reader and its epoch file pattern. The index
%   is read twice each time (a second read answers from the stored rows).
%
%   R.checks lists every comparison (denominator first in the printout);
%   R.mismatches the ones that differ. Jess Haley, 2026-11-09: "Build the
%   derived index".

R = struct('label', label, 'checks', {{}}, 'mismatches', {{}});
root = tempname();
mkdir(root);
clean = onCleanup(@() rmdir(root, 's'));
copyfile(char(migratedNdiDir), fullfile(root, '.ndi'));
for f = {'unique_reference.txt', 'reference.txt', '.migrate.lock'}
    p = fullfile(root, '.ndi', f{1});
    if isfile(p); delete(p); end
end
dbs = dir(fullfile(root, '.ndi', '*.sqlite'));
sids = {};
v2file = '';
for k = 1:numel(dbs)
    try
        db = did2.database.sqlitedb(fullfile(dbs(k).folder, dbs(k).name));
    catch
        continue;   % the v1 database beside it
    end
    docs = db.search(did2.query('', 'isa', 'acquisition_system'));
    for i = 1:numel(docs)
        sids{end+1} = char(did2.schema.cache.sessionIdOf(docs{i}.toStruct())); %#ok<AGROW>
    end
    v2file = fullfile(dbs(k).folder, dbs(k).name);
    db.close();
end
% the changes are made through a connection of the test's own to the same
% file (the session's database is not reachable from outside the session)
raw = did2.database.sqlitedb(v2file);
cleanRaw = onCleanup(@() raw.close());
sids = unique(sids(~cellfun(@isempty, sids)), 'stable');
fprintf('\n  EPOCH INDEX EQUIVALENCE (%s): %d session(s) with an acquisition system\n', label, numel(sids));
for i = 1:numel(sids)
    S = ndi.session.dir('epoch index check', root, sids{i});
    if ~ndi.vintage.epochIndex('available', S)
        R.mismatches{end+1} = sprintf('session %s: no derived-row store (DID-matlab too old?)', sids{i});
        continue;
    end
    devs = S.daqsystem_load('name', '(.*)');
    if ~iscell(devs); devs = {devs}; end
    for k = 1:numel(devs)
        dev = devs{k};
        sys = struct('id', char(dev.id()), 'nav', char(dev.filenavigator.id()), ...
            'cls', char(dev.filenavigator.epochprobemap_class), 'reader', char(dev.daqreader.id()));
        R = compareOnce(R, S, sys, 'as stored');
        targets = pickTargets(S, sys, raw);
        names = fieldnames(targets);
        for t = 1:numel(names)
            id = targets.(names{t});
            if isempty(id)
                R.checks{end+1} = sprintf('%s: no %s to change (not measured)', sys.id, names{t});
                continue;
            end
            db = raw;
            d = db.get(id);
            db.remove(id);
            R = compareOnce(R, S, sys, sprintf('after removing the %s %s', names{t}, id));
            db.add({d}, 'Validate', false);
            R = compareOnce(R, S, sys, sprintf('after re-adding the %s %s', names{t}, id));
        end
    end
end
fprintf('    %d comparison(s), %d mismatch(es)\n', numel(R.checks), numel(R.mismatches));
for k = 1:numel(R.mismatches)
    fprintf('      MISMATCH %s\n', R.mismatches{k});
end
end

function R = compareOnce(R, S, sys, when)
docs = S.database_search(ndi.vintage.ingestedQuery(sys.nav, S.id()));
fresh = ndi.vintage.ingestedEpochs(S, docs, sys.cls, 'UseIndex', false);
for pass = 1:2
    viaIndex = ndi.vintage.ingestedEpochs(S, docs, sys.cls);
    R = record(R, isequal(fresh, viaIndex), sprintf('%s navigator %s, read %d (%d epochs)', ...
        sys.id, when, pass, numel(fresh)));
end
ids = {fresh(strcmp({fresh.vintage}, 'V_eta')).epoch_id};
ids = ids(~cellfun(@isempty, ids));
A0 = ndi.vintage.ingestedArchives(S, sys.reader, ids, 'ClocksOnly', true, 'UseIndex', false);
for pass = 1:2
    A1 = ndi.vintage.ingestedArchives(S, sys.reader, ids, 'ClocksOnly', true);
    R = record(R, sameClocks(A0, A1), sprintf('%s reader %s, read %d (%d epochs)', ...
        sys.id, when, pass, A0.Count));
end
end

function R = record(R, ok, what)
R.checks{end+1} = what;
if ~ok
    R.mismatches{end+1} = what;
end
end

function tf = sameClocks(A, B)
tf = isequal(sort(A.keys), sort(B.keys));
if ~tf; return; end
k = A.keys;
for i = 1:numel(k)
    a = A(k{i}); b = B(k{i});
    if ~isequal(a.epoch_id, b.epoch_id) || ~isequal(a.epochclock, b.epochclock) ...
            || ~isequal(a.t0_t1, b.t0_t1) || ~isequal(a.clock_problem, b.clock_problem) ...
            || ~isequal(a.vintage, b.vintage) || ~isequal(a.channels, b.channels) ...
            || ~isequal(a.bodies.keys, b.bodies.keys)
        tf = false;
        return;
    end
end
end

function T = pickTargets(S, sys, db)
% one document of every kind the rows are read from, for this system
T = struct('manifest', '', 'epoch', '', 'anchor', '', 'statement', '', 'wiring', '', ...
    'body', '', 'probe', '', 'subject', '', 'assertion', '', 'system', sys.id, ...
    'reader', sys.reader, 'pattern', sys.nav);
docs = S.database_search(ndi.vintage.ingestedQuery(sys.nav, S.id()));
for k = 1:numel(docs)
    p = docs{k}.document_properties;
    if ~isfield(p, 'ingestion_manifest'); continue; end
    T.manifest = char(p.base.id);
    T.epoch = char(docs{k}.dependency_value('epoch_id', 'ErrorIfNotFound', 0));
    break;
end
if isempty(T.epoch); return; end
a = db.searchIds(did2.query('', 'isa', 'relative_time_reference') & ...
    did2.query('', 'depends_on', 'referent_id', T.epoch));
if isempty(a); return; end
for j = 1:numel(a)
    st = db.search(did2.query('', 'depends_on', 'time_reference_id', a{j}));
    for m = 1:numel(st)
        s = st{m}.toStruct();
        c = s.document_class.class_name;
        if strcmp(c, 'directed_relation') && isempty(T.wiring)
            T.wiring = char(s.base.id);
        elseif ~strcmp(c, 'directed_relation') && isempty(T.statement) && ~isempty(edge(s, 'instrument_id'))
            T.statement = char(s.base.id);
            T.anchor = a{j};
            T.probe = edge(s, 'instrument_id');
            T.subject = edge(s, 'entity_id');
        end
    end
end
if isempty(T.anchor); T.anchor = a{1}; end
if ~isempty(T.statement)
    b = db.searchIds(did2.query('', 'depends_on', 'owner_id', T.statement));
    if ~isempty(b); T.body = b{1}; end
end
if ~isempty(T.probe)
    as = db.searchIds(did2.query('', 'isa', 'assertion') & did2.query('', 'depends_on', 'entity_id', T.probe));
    if ~isempty(as); T.assertion = as{1}; end
end
end

function v = edge(s, name)
v = '';
if ~isfield(s, 'depends_on'); return; end
d = s.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    if strcmp(d{k}.name, name)
        if isfield(d{k}, 'document_id'); v = char(d{k}.document_id); else; v = char(d{k}.value); end
        return;
    end
end
end
