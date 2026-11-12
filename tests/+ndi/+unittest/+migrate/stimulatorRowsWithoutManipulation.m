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
%   then removes every per-epoch Stimulator manipulation (a manipulation
%   whose instrument is a migrated stimulator element and that names a rig,
%   `acquisition_system_id`: DID-matlab resolveEpochProbemap mkManipulation)
%   and reads them all again in freshly opened sessions, the navigator's
%   also through the derived index. Decided by Jess Haley, 2026-11-09,
%   did-schema did_v2_standing_wiring_plan.md [stimulator manipulation
%   dropped]: the manipulation is no longer written once the build confirms
%   it carries nothing the wiring relation and the stimulator element do
%   not. A manipulation that owns a data body is not removed, and is
%   counted (it would carry something).
%
%   R.checks lists every comparison (denominator first in the printout);
%   R.mismatches the ones that differ; R.removed the number of manipulations
%   removed, R.withBody the number left because they own a body.

R = struct('label', label, 'checks', {{}}, 'mismatches', {{}}, 'removed', 0, ...
    'withBody', 0, 'stimulators', 0);
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

% ---- before: as migrated, and the manipulations to remove --------------
before = cell(1, numel(sids));
remove = {};
for i = 1:numel(sids)
    S = ndi.session.dir('stimulator rows', root, sids{i});
    before{i} = readAll(S);
    R.stimulators = R.stimulators + numel(before{i}.stimulators);
    [ids, nBody] = stimulatorManipulations(S);
    remove = [remove, ids]; %#ok<AGROW>
    R.withBody = R.withBody + nBody;
end
remove = unique(remove, 'stable');
fprintf('    %d stimulator probe(s); %d Stimulator manipulation(s) to remove, %d left (own a body)\n', ...
    R.stimulators, numel(remove), R.withBody);

% ---- remove them, through a connection of the test's own --------------
raw = did2.database.sqlitedb(v2file);
for k = 1:numel(remove)
    raw.remove(remove{k});
end
raw.close();
R.removed = numel(remove);

% ---- after: freshly opened, the same answers ---------------------------
for i = 1:numel(sids)
    S = ndi.session.dir('stimulator rows after', root, sids{i});
    S.cache.clear();
    a = readAll(S);
    b = before{i};
    R = record(R, isequal(a.stimulators, b.stimulators), sprintf( ...
        'session %s: getprobes stimulator (%d probe(s) before, %d after)', sids{i}, ...
        numel(b.stimulators), numel(a.stimulators)));
    if ~isequal(a.stimulators, b.stimulators)
        showDiff('stimulator', cellfun(@probeText, b.stimulators, 'UniformOutput', false), ...
            cellfun(@probeText, a.stimulators, 'UniformOutput', false));
    end
    for s = 1:numel(b.systems)
        bs = b.systems(s);
        as = a.systems(strcmp({a.systems.id}, bs.id));
        if isempty(as)
            R = record(R, false, sprintf('session %s system %s: not found after', sids{i}, bs.id));
            continue;
        end
        R = record(R, isequal(as.epochs, bs.epochs) && isequal(as.err, bs.err), sprintf( ...
            'session %s system %s: navigator (%d epochs, %d rows%s)', sids{i}, bs.name, ...
            numel(bs.epochs), nRows(bs.epochs), errNote(bs.err)));
        if ~isequal(as.epochs, bs.epochs)
            showDiff('row', epochTexts(bs.epochs), epochTexts(as.epochs));
        end
        R = record(R, isequal(as.indexed, as.epochs), sprintf( ...
            'session %s system %s: navigator through the derived index after', sids{i}, bs.name));
        R = record(R, isequal(as.clocks, bs.clocks) && isequal(as.clockErr, bs.clockErr), sprintf( ...
            'session %s system %s: reader (%d epochs with a v2 archive%s)', sids{i}, bs.name, ...
            numel(bs.clocks), errNote(bs.clockErr)));
    end
end
fprintf('    %d comparison(s), %d mismatch(es)\n', numel(R.checks), numel(R.mismatches));
for k = 1:numel(R.mismatches)
    fprintf('      MISMATCH %s\n', R.mismatches{k});
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

function [ids, nBody] = stimulatorManipulations(S)
% the per-epoch Stimulator manipulations of this session: instrument a
% migrated stimulator element, naming a rig; those that own a data body are
% left (nBody)
ids = {};
nBody = 0;
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
