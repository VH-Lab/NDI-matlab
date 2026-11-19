function R = stimulatorRowsWithoutManipulation(migratedNdiDir, label)
%STIMULATORROWSWITHOUTMANIPULATION A migrated corpus reads the same without its Stimulator manipulations.
%
%   R = ndi.unittest.migrate.stimulatorRowsWithoutManipulation(MIGRATEDNDIDIR, LABEL)
%   copies the migrated .ndi folder and, for every session with an
%   acquisition system, reads
%
%     each system's ingested epochs  ndi.vintage.ingestedEpochs(..., 'UseIndex', false):
%                                    epoch id and probe-map rows, compared as
%                                    a set ([probe map rows compared as a set])
%     each system's reader clocks    ndi.vintage.ingestedArchives(..., 'ClocksOnly',
%                                    true, 'UseIndex', false): which epochs
%                                    have a v2 archive, and their clocks
%     the stimulators                getprobes('type', 'stimulator'): name,
%                                    reference and the epoch ids of each
%                                    one's epoch table
%
%   in three states of a copy:
%
%     as migrated     the decided shape: DID-matlab #466 (1048e449) writes
%                     no Stimulator manipulation for a row its wiring and
%                     element hold, so only the ones it keeps (a row with no
%                     wiring, another subject or another type) are there
%     with old data   one per-epoch Stimulator manipulation added for every
%                     stimulator wiring relation and epoch that has none, as
%                     DID-matlab's resolveEpochProbemap mkManipulation wrote
%                     before #466 (a session migrated before it)
%     without         every per-epoch Stimulator manipulation removed (a
%                     manipulation whose instrument is a migrated stimulator
%                     element and that names a rig, `acquisition_system_id`)
%
%   and checks that "without" reads what "with old data" reads, and that
%   "with old data" reads what the decided shape reads; the navigator is
%   also read through the derived index. Decided by Jess Haley, 2026-11-09,
%   did-schema did_v2_standing_wiring_plan.md [stimulator manipulation
%   dropped]: the manipulation is no longer written once the build confirms
%   it carries nothing the wiring relation and the stimulator element do
%   not. A manipulation that owns a data body is not removed, and is
%   counted (it would carry something).
%
%   R.checks lists every comparison (denominator first in the printout);
%   R.mismatches the ones that differ; R.written the Stimulator
%   manipulations the migration wrote, R.added the old-data ones added,
%   R.removed the number removed (written and added), R.withBody the number
%   left because they own a body.

R = struct('label', label, 'checks', {{}}, 'mismatches', {{}}, 'removed', 0, ...
    'written', 0, 'added', 0, 'withBody', 0, 'stimulators', 0);
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
    if ~isempty(docs); v2file = fullfile(dbs(k).folder, dbs(k).name); end
    db.close();
end
sids = unique(sids(~cellfun(@isempty, sids)), 'stable');
fprintf('\n  STIMULATOR ROWS WITHOUT THE MANIPULATION (%s): %d session(s) with an acquisition system\n', ...
    label, numel(sids));
if isempty(v2file)
    R.mismatches{end+1} = 'no v2 database in the migrated folder';
    return;
end

% ---- as migrated: the reads, the manipulations it wrote, the old data ----
migrated = cell(1, numel(sids));
written = {};
toAdd = {};
for i = 1:numel(sids)
    S = ndi.session.dir('stimulator rows', root, sids{i});
    migrated{i} = readAll(S);
    R.stimulators = R.stimulators + numel(migrated{i}.stimulators);
    [ids, nBody, old] = stimulatorManipulations(S);
    written = [written, ids]; %#ok<AGROW>
    toAdd = [toAdd, old]; %#ok<AGROW>
    R.withBody = R.withBody + nBody;
end
written = unique(written, 'stable');
R.written = numel(written);
R.added = numel(toAdd);
fprintf(['    %d stimulator probe(s); %d Stimulator manipulation(s) written by the migration, ' ...
    '%d old-data one(s) added, %d left (own a body)\n'], ...
    R.stimulators, R.written, R.added, R.withBody);

% ---- with old data: added through a connection of the test's own --------
added = cellfun(@(d) char(d.get('base.id')), toAdd, 'UniformOutput', false);
if ~isempty(toAdd)
    raw = did2.database.sqlitedb(v2file);
    raw.add(toAdd);
    raw.close();
end
withOld = cell(1, numel(sids));
for i = 1:numel(sids)
    S = ndi.session.dir('stimulator rows with old data', root, sids{i});
    S.cache.clear();
    withOld{i} = readAll(S);
end

% ---- without: every Stimulator manipulation removed ---------------------
remove = unique([written, added], 'stable');
raw = did2.database.sqlitedb(v2file);
for k = 1:numel(remove)
    raw.remove(remove{k});
end
raw.close();
R.removed = numel(remove);

% ---- freshly opened, the same answers ------------------------------------
for i = 1:numel(sids)
    S = ndi.session.dir('stimulator rows after', root, sids{i});
    S.cache.clear();
    a = readAll(S);
    R = compareReads(R, sids{i}, 'with old data vs without', withOld{i}, a);
    R = compareReads(R, sids{i}, 'as migrated vs with old data', migrated{i}, withOld{i});
end
fprintf('    %d comparison(s), %d mismatch(es)\n', numel(R.checks), numel(R.mismatches));
for k = 1:numel(R.mismatches)
    fprintf('      MISMATCH %s\n', R.mismatches{k});
end
end

function R = compareReads(R, sid, what, b, a)
% B the reads before, A after, of one session
R = record(R, isequal(a.stimulators, b.stimulators), sprintf( ...
    'session %s, %s: getprobes stimulator (%d probe(s) before, %d after)', sid, what, ...
    numel(b.stimulators), numel(a.stimulators)));
if ~isequal(a.stimulators, b.stimulators)
    showDiff('stimulator', cellfun(@probeText, b.stimulators, 'UniformOutput', false), ...
        cellfun(@probeText, a.stimulators, 'UniformOutput', false));
end
for s = 1:numel(b.systems)
    bs = b.systems(s);
    as = a.systems(strcmp({a.systems.id}, bs.id));
    if isempty(as)
        R = record(R, false, sprintf('session %s, %s, system %s: not found after', sid, what, bs.id));
        continue;
    end
    R = record(R, isequal(as.epochs, bs.epochs) && isequal(as.err, bs.err), sprintf( ...
        'session %s, %s, system %s: navigator (%d epochs, %d rows%s)', sid, what, bs.name, ...
        numel(bs.epochs), nRows(bs.epochs), errNote(bs.err)));
    if ~isequal(as.epochs, bs.epochs)
        showDiff('row', epochTexts(bs.epochs), epochTexts(as.epochs));
    end
    R = record(R, isequal(as.indexed, as.epochs), sprintf( ...
        'session %s, %s, system %s: navigator through the derived index after', sid, what, bs.name));
    R = record(R, isequal(as.clocks, bs.clocks) && isequal(as.clockErr, bs.clockErr), sprintf( ...
        'session %s, %s, system %s: reader (%d epochs with a v2 archive%s)', sid, what, bs.name, ...
        numel(bs.clocks), errNote(bs.clockErr)));
end
end

function A = readAll(S)
% each system's navigator rows and reader clocks, and the stimulators
A = struct('systems', struct('id', {}, 'name', {}, 'epochs', {}, 'indexed', {}, 'err', {}, ...
    'clocks', {}, 'clockErr', {}), 'stimulators', {{}});
devs = S.daqsystem_load('name', '(.*)');
if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
for k = 1:numel(devs)
    dev = devs{k};
    nav = dev.filenavigator;
    cls = nav.epochprobemap_class;
    docs = S.database_search(ndi.vintage.ingestedQuery(nav.id(), S.id()));
    [E, err] = attempt(@() ndi.vintage.ingestedEpochs(S, docs, cls, 'UseIndex', false));
    [EI, ~] = attempt(@() ndi.vintage.ingestedEpochs(S, docs, cls));
    epochs = epochRows(E);
    clocks = {}; clockErr = '';
    if isempty(err) && (isa(dev, 'ndi.daq.system.mfdaq') || isa(dev, 'ndi.daq.system.image'))
        ids = {};
        if ~isempty(E)
            ids = {E(strcmp({E.vintage}, 'V_eta')).epoch_id};
            ids = ids(~cellfun(@isempty, ids));
        end
        [M, clockErr] = attempt(@() ndi.vintage.ingestedArchives(S, dev.daqreader.id(), ids, ...
            'ClocksOnly', true, 'UseIndex', false));
        if isempty(clockErr)
            keys = sort(M.keys);
            for i = 1:numel(keys)
                m = M(keys{i});
                clocks{end+1} = {keys{i}, m.epochclock, m.t0_t1, m.clock_problem}; %#ok<AGROW>
            end
        end
    end
    A.systems(end+1) = struct('id', char(dev.id()), 'name', char(dev.name), 'epochs', {epochs}, ...
        'indexed', {epochRows(EI)}, 'err', err, 'clocks', {clocks}, 'clockErr', clockErr);
end
probes = S.getprobes('type', 'stimulator');
st = {};
for k = 1:numel(probes)
    et = probes{k}.epochtable();
    st{end+1} = {char(probes{k}.name), double(probes{k}.reference), sort({et.epoch_id})}; %#ok<AGROW>
end
if ~isempty(st)
    keys = cellfun(@(x) sprintf('%s|%g', x{1}, x{2}), st, 'UniformOutput', false);
    [~, o] = sort(keys);
    st = st(o);
end
A.stimulators = st;
end

function e = epochRows(E)
% each epoch's id and its probe-map rows as a sorted cellstr (a set)
e = {};
for k = 1:numel(E)
    rows = {};
    pm = E(k).probemap;
    for r = 1:numel(pm)
        rows{end+1} = strjoin({char(pm(r).name), num2str(double(pm(r).reference)), ...
            char(pm(r).type), char(pm(r).devicestring), char(pm(r).subjectstring)}, '|'); %#ok<AGROW>
    end
    e{end+1} = {char(E(k).epoch_id), sort(rows)}; %#ok<AGROW>
end
if ~isempty(e)
    [~, o] = sort(cellfun(@(x) x{1}, e, 'UniformOutput', false));
    e = e(o);
end
end

function showDiff(what, before, after)
% up to five entries only before and five only after
onlyB = setdiff(before, after);
onlyA = setdiff(after, before);
fprintf('      %s entries only before: %d, only after: %d\n', what, numel(onlyB), numel(onlyA));
for k = 1:min(5, numel(onlyB)); fprintf('        before only: %s\n', onlyB{k}); end
for k = 1:min(5, numel(onlyA)); fprintf('        after only:  %s\n', onlyA{k}); end
end

function t = probeText(p)
t = sprintf('%s|%g|%d epochs: %s', p{1}, p{2}, numel(p{3}), strjoin(p{3}(1:min(3, end)), ','));
end

function t = epochTexts(e)
% one text per (epoch, row)
t = {};
for k = 1:numel(e)
    for r = 1:numel(e{k}{2})
        t{end+1} = [e{k}{1} ' :: ' e{k}{2}{r}]; %#ok<AGROW>
    end
    if isempty(e{k}{2}); t{end+1} = [e{k}{1} ' :: (no rows)']; end %#ok<AGROW>
end
end

function n = nRows(e)
n = 0;
for k = 1:numel(e)
    n = n + numel(e{k}{2});
end
end

function [ids, nBody, old] = stimulatorManipulations(S)
% the per-epoch Stimulator manipulations of this session: instrument a
% migrated stimulator element, naming a rig; those that own a data body are
% left (nBody). OLD: the did2.documents of the old-data manipulations to add,
% one per stimulator wiring relation and epoch that no such manipulation
% names (oldManipulations)
ids = {};
nBody = 0;
old = {};
% the migrated stimulator elements: the probes (ndi.vintage.elementSubjectDocs
% 'probe') whose element type is stimulator (ndi.vintage.elementFields). Not
% elementSubjectDocs(S, 'stimulator'): that matched the "ndi element class"
% assertion's class name, which DID-matlab no longer writes ([ndi element
% class not kept], [element recognised by its links], Jess Haley, 2026-11-10,
% did-schema did_v2_go_forward_class_audit.md); a probe's rebuilt class stem
% is ndi.probe. and does not name its type.
stims = ndi.vintage.elementSubjectDocs(S, 'probe');
stims = stims(cellfun(@(d) strcmp(char(ndi.vintage.elementFields(d, S).type), 'stimulator'), stims));
if isempty(stims); return; end
stimIds = cellfun(@(d) char(d.id()), stims, 'UniformOutput', false);
found = S.database_search(ndi.v2.isaQuery('manipulation') & ...
    ndi.vintage.edgeIn('instrument_id', stimIds));
found = found(cellfun(@(d) ~isempty(ndi.vintage.edgeTargets(d, 'acquisition_system_id')), found));
old = oldManipulations(S, stims, found);
if isempty(found); return; end
mids = cellfun(@(d) char(d.id()), found, 'UniformOutput', false);
owned = S.database_search(ndi.query('', 'isa', 'data_body', '') & ndi.vintage.edgeIn('owner_id', mids));
owners = {};
for k = 1:numel(owned)
    owners = [owners, ndi.vintage.edgeTargets(owned{k}, 'owner_id')]; %#ok<AGROW>
end
hasBody = ismember(mids, owners);
nBody = sum(hasBody);
ids = mids(~hasBody);
end

function docs = oldManipulations(S, stims, existing)
% old data: per stimulator wiring relation (a `connected to`, RO:0002170,
% directed_relation from the rig -- its device, or the acquisition_system
% migrated before -- parent_id, to the stimulator, child_id)
% and per epoch it is timed by (time_reference_id), the Stimulator
% manipulation DID-matlab's resolveEpochProbemap wrote before #466
% (mkManipulation, the same did2.build.statement call): the stimulator's
% element type as variable and term value, about the element's subject, the
% stimulator as instrument, the rig as acquisition system, timed by the
% epoch anchor. A (stimulator, epoch) that EXISTING already names (a
% manipulation the migration kept: no wiring, another subject or another
% type) gets none.
docs = {};
have = {};
for k = 1:numel(existing)
    inst = ndi.vintage.edgeTargets(existing{k}, 'instrument_id');
    tr = ndi.vintage.edgeTargets(existing{k}, 'time_reference_id');
    for i = 1:numel(inst)
        for j = 1:numel(tr)
            have{end+1} = [char(inst{i}) '|' char(tr{j})]; %#ok<AGROW>
        end
    end
end
for s = 1:numel(stims)
    stimId = char(stims{s}.id());
    F = ndi.vintage.elementFields(stims{s}, S);
    subjectId = char(F.subject_id);
    if isempty(subjectId); continue; end   % read without a subject either way
    typeTerm = did2.convert.registeredTerm('', char(F.type));
    found = S.database_search(ndi.query('', 'isa', 'directed_relation', '') & ...
        ndi.query('', 'depends_on', 'child_id', stimId));
    found = found(cellfun(@isWiring, found));
    for w = 1:numel(found)
        rig = ndi.vintage.edgeTargets(found{w}, 'parent_id');
        anchors = ndi.vintage.edgeTargets(found{w}, 'time_reference_id');
        if ~isscalar(rig); continue; end
        % the wiring names the rig's device entity since [acquisition system
        % is a device entity] (Jess Haley 2026-11-19); the old manipulation
        % named the acquisition_system that points at it by `device_id`
        sysOf = ndi.vintage.rigSystems(S, rig);
        if isKey(sysOf, rig{1}); rig = {sysOf(rig{1})}; end
        for a = 1:numel(anchors)
            key = [stimId '|' char(anchors{a})];
            if ismember(key, have); continue; end
            have{end+1} = key; %#ok<AGROW>
            m = did2.build.statement('manipulation', subjectId, typeTerm, typeTerm, ...
                'TimeReferenceIds', anchors(a), 'InstrumentId', stimId, ...
                'AcquisitionSystemId', char(rig{1}), 'SessionId', char(S.id()), ...
                'Validate', false, 'ValueKind', 'term');
            docs{end+1} = did2.document(m); %#ok<AGROW>
        end
    end
end
end

function tf = isWiring(d)
% a directed_relation `connected to` (RO:0002170)
tf = false;
p = d.document_properties;
if ~isfield(p, 'directed_relation') || ~isfield(p.directed_relation, 'relation'); return; end
r = p.directed_relation.relation;
tf = isstruct(r) && isfield(r, 'node') && strcmpi(char(r.node), 'RO:0002170');
end

function [v, err] = attempt(f)
v = []; err = '';
try
    v = f();
catch ME
    err = [ME.identifier ': ' ME.message];
end
end

function t = errNote(err)
t = '';
if ~isempty(err); t = sprintf('; both sides must raise: %s', err); end
end

function R = record(R, ok, what)
R.checks{end+1} = what;
if ~ok
    R.mismatches{end+1} = what;
end
end
