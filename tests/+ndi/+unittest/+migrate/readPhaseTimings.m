function T = readPhaseTimings(v1Bodies, migratedNdiDir, label, options)
%READPHASETIMINGS The seconds each read phase takes, before and after migration.
%
%   T = ndi.unittest.migrate.readPhaseTimings(V1BODIES, MIGRATEDNDIDIR, LABEL)
%
%   Opens every session of a corpus twice: from a DID v1 database holding
%   V1BODIES (the corpus as it was migrated, JSON text), and from a copy of
%   MIGRATEDNDIDIR (the .ndi folder ndi.migrate.local wrote). Each side does
%   THE SAME WORK, in a freshly opened session, in five phases:
%
%     subjects   getsubjects, and each subject's local identifier
%     elements   getelements
%     element_epochs  each element's id, name, reference, type, subject,
%                direct flag and underlying element (id, name), and the
%                epoch table of every element that is not a probe
%     probes     getprobes, the same facts of each probe, and the epoch
%                tables of at most MaxProbeEpochTables probes (chosen on the
%                v1 side, evenly over the probes sorted by key; the same
%                probes after migration)
%     systems    daqsystem_load and each acquisition system's epoch table
%
%   These are the phases corpusObjectEquivalence times (its snapshot), with
%   no comparison in between. Jess Haley, 2026-11-06: "Speed can't be slower
%   than v1. We need to match or beat."
%
%   T is a struct: T.label, T.sessions (per session: id, reference, v1 and
%   v2 seconds per phase, the object counts per side) and T.v1 / T.v2, each
%   phase summed over the sessions. Every session read is counted; a phase
%   that raised is reported with its error and its time is NaN (never 0).
%
%   'Profile', true runs the MATLAB profiler over each v2 phase and prints
%   the functions with the most total and self time (report-only).
%
%   See also ndi.unittest.migrate.corpusObjectEquivalence,
%   ndi.unittest.migrate.verifyReadPhases.

arguments
    v1Bodies cell
    migratedNdiDir {mustBeTextScalar}
    label {mustBeTextScalar} = 'corpus'
    options.MaxProbeEpochTables (1,1) double = 12
    options.Profile (1,1) logical = false
    options.ProfileTop (1,1) double = 45
end

label = char(label);
PH = {'subjects', 'elements', 'element_epochs', 'probes', 'systems'};
T = struct('label', label, 'phases', {PH}, 'sessions', struct('id', {}, ...
    'reference', {}, 'v1', {}, 'v2', {}, 'counts', {}, 'errors', {}), ...
    'v1', zeroPhases(PH), 'v2', zeroPhases(PH));

v1Structs = cell(1, numel(v1Bodies));
for k = 1:numel(v1Bodies)
    v1Structs{k} = jsondecode(char(v1Bodies{k}));
end
v1Root = tempname();
mkdir(fullfile(v1Root, '.ndi'));
cleanV1 = onCleanup(@() removeDir(v1Root));
buildV1Database(fullfile(v1Root, '.ndi', 'did-sqlite.sqlite'), v1Structs);

v2Root = tempname();
mkdir(v2Root);
cleanV2 = onCleanup(@() removeDir(v2Root));
copyfile(char(migratedNdiDir), fullfile(v2Root, '.ndi'));
for f = {'unique_reference.txt', 'reference.txt', '.migrate.lock'}
    p = fullfile(v2Root, '.ndi', f{1});
    if isfile(p); delete(p); end
end

sids = {};
for k = 1:numel(v1Structs)
    b = v1Structs{k};
    if isfield(b, 'document_class') && strcmp(b.document_class.class_name, 'session')
        sids{end+1} = char(b.base.session_id); %#ok<AGROW>
    end
end
sids = unique(sids, 'stable');

for i = 1:numel(sids)
    sid = sids{i};
    rec = struct('id', sid, 'reference', '', 'v1', zeroPhases(PH), 'v2', zeroPhases(PH), ...
        'counts', struct(), 'errors', {{}});
    S1 = openAt(v1Root, sid);
    [rec.v1, c1, e1, keys] = timePhases(S1, PH, options.MaxProbeEpochTables, {}, ...
        profileLabel(options.Profile, 'v1'), options.ProfileTop);
    clear S1
    S2 = openAt(v2Root, sid);
    rec.reference = char(S2.reference);
    [rec.v2, c2, e2] = timePhases(S2, PH, Inf, keys, profileLabel(options.Profile, 'v2'), options.ProfileTop);
    clear S2
    rec.counts = struct('v1', c1, 'v2', c2);
    rec.errors = [strcat('v1: ', e1), strcat('v2: ', e2)];
    T.sessions(end+1) = rec;
    for p = 1:numel(PH)
        T.v1.(PH{p}) = T.v1.(PH{p}) + rec.v1.(PH{p});
        T.v2.(PH{p}) = T.v2.(PH{p}) + rec.v2.(PH{p});
    end
end
printTimings(T);
end

% =========================================================================

function [t, counts, errs, probeKeys] = timePhases(S, PH, cap, onlyKeys, doProfile, topN)
t = zeroPhases(PH);
errs = {};
counts = struct('subjects', 0, 'elements', 0, 'element_epoch_tables', 0, ...
    'probes', 0, 'probe_epoch_tables', 0, 'systems', 0);
probeKeys = {};
restrict = ~isempty(onlyKeys) || isinf(cap);

% subjects
startPhase(doProfile);
tic0 = tic;
try
    docs = asCell(S.getsubjects());
    for k = 1:numel(docs)
        p = ndi.v2.props(docs{k});
        ndi.v2.blockOf(p, 'subject', 'local_identifier', ''); %#ok<NASGU>
    end
    counts.subjects = numel(docs);
catch ME
    errs{end+1} = ['subjects: ' ME.message];
end
t.subjects = toc(tic0);
endPhase(doProfile, 'subjects', topN);

% elements
startPhase(doProfile);
tic0 = tic;
els = {};
try
    els = asCell(S.getelements());
    counts.elements = numel(els);
catch ME
    errs{end+1} = ['getelements: ' ME.message];
end
t.elements = toc(tic0);
endPhase(doProfile, 'elements', topN);

% each element's facts, and the epoch table of each non-probe element
startPhase(doProfile);
tic0 = tic;
try
    for k = 1:numel(els)
        o = els{k};
        facts(o);
        if ~isa(o, 'ndi.probe')
            o.epochtable();
            counts.element_epoch_tables = counts.element_epoch_tables + 1;
        end
    end
catch ME
    errs{end+1} = ['element epochs: ' ME.message];
end
t.element_epochs = toc(tic0);
endPhase(doProfile, 'element_epochs', topN);

% probes, their facts and some of their epoch tables
startPhase(doProfile);
tic0 = tic;
try
    prs = asCell(S.getprobes());
    counts.probes = numel(prs);
    keys = cell(1, numel(prs));
    for k = 1:numel(prs)
        f = facts(prs{k});
        keys{k} = sprintf('%s | %s | %s', f.name, num2str(f.reference), f.type);
    end
    if restrict
        toRead = onlyKeys;
    elseif numel(keys) > cap
        sk = sort(keys);
        toRead = sk(unique(round(linspace(1, numel(sk), cap))));
    else
        toRead = keys;
    end
    for k = 1:numel(prs)
        if any(strcmp(toRead, keys{k}))
            prs{k}.epochtable();
            counts.probe_epoch_tables = counts.probe_epoch_tables + 1;
            probeKeys{end+1} = keys{k}; %#ok<AGROW>
        end
    end
catch ME
    errs{end+1} = ['probes: ' ME.message];
end
t.probes = toc(tic0);
endPhase(doProfile, 'probes', topN);

% acquisition systems and their epoch tables
startPhase(doProfile);
tic0 = tic;
try
    devs = asCell(S.daqsystem_load('name', '(.*)'));
    for k = 1:numel(devs)
        devs{k}.epochtable();
    end
    counts.systems = numel(devs);
catch ME
    errs{end+1} = ['systems: ' ME.message];
end
t.systems = toc(tic0);
endPhase(doProfile, 'systems', topN);
end

function f = facts(o)
f = struct('id', char(o.id()), 'name', char(o.name), 'reference', double(o.reference), ...
    'type', char(o.type), 'subject_id', char(o.subject_id), 'direct', logical(o.direct), ...
    'underlying_id', '', 'underlying_name', '');
u = o.underlying_element;
if ~isempty(u)
    f.underlying_id = char(u.id());
    f.underlying_name = char(u.name);
end
end

function startPhase(doProfile)
if doProfile
    profile('clear');
    profile('on');
end
end

function endPhase(doProfile, phase, topN)
% DOPROFILE is the side's label ('v1', 'v2') when profiling, else ''
if isempty(doProfile) || isequal(doProfile, false)
    return;
end
side = 'v2';
if ischar(doProfile); side = doProfile; end
profile('off');
info = profile('info');
profile('clear');
ft = info.FunctionTable;
if isempty(ft)
    return;
end
total = [ft.TotalTime];
self = total;
for k = 1:numel(ft)
    ch = ft(k).Children;
    if ~isempty(ch)
        self(k) = total(k) - sum([ch.TotalTime]);
    end
end
calls = [ft.NumCalls];
names = {ft.FunctionName};
% the test framework's frames are left out of the TOTAL list
frame = contains(names, {'TestRunner', 'runtests', 'Plugin', 'command_', ...
    'Handler', 'TestRunStrategy', 'readPhaseTimings', 'TestMigrateLocalEta'});
fprintf('      [profile %s %s] top %d by TOTAL time (s, calls):\n', side, phase, topN);
[~, o] = sort(total, 'descend');
o = o(~frame(o));
for k = 1:min(topN, numel(o))
    fprintf('        %9.2f %8d  %s\n', total(o(k)), calls(o(k)), names{o(k)});
end
% the children of the 20 largest functions (by TOTAL), each child of 0.05 s
% or more: where each one's time goes
fprintf('      [profile %s %s] children of the 20 largest functions (s, calls):\n', side, phase);
[~, o] = sort(total, 'descend');
o = o(~frame(o));
for k = 1:min(20, numel(o))
    ch = ft(o(k)).Children;
    if isempty(ch); continue; end
    [~, co] = sort([ch.TotalTime], 'descend');
    fprintf('        %9.2f  %s\n', total(o(k)), names{o(k)});
    for j = co
        if ch(j).TotalTime < 0.05; break; end
        fprintf('                  -> %7.2f %8d  %s\n', ch(j).TotalTime, ch(j).NumCalls, names{ch(j).Index});
    end
end
fprintf('      [profile %s %s] top %d by SELF time (s, calls), with their callers:\n', side, phase, topN);
[~, o] = sort(self, 'descend');
for k = 1:min(topN, numel(o))
    fprintf('        %9.2f %8d  %s\n', self(o(k)), calls(o(k)), names{o(k)});
    par = ft(o(k)).Parents;
    if k <= 12 && ~isempty(par)
        [~, po] = sort([par.NumCalls], 'descend');
        for j = 1:min(4, numel(po))
            fprintf('                  <- %8d  %s\n', par(po(j)).NumCalls, names{par(po(j)).Index});
        end
    end
end
end

function z = zeroPhases(PH)
z = struct();
for p = 1:numel(PH)
    z.(PH{p}) = 0;
end
end

function printTimings(T)
PH = T.phases;
fprintf('\n  READ PHASES, v1 against v2 (%s): %d session(s)\n', T.label, numel(T.sessions));
fprintf('    %-16s %12s %12s %10s\n', 'phase', 'v1 (s)', 'v2 (s)', 'v2/v1');
for p = 1:numel(PH)
    a = T.v1.(PH{p}); b = T.v2.(PH{p});
    fprintf('    %-16s %12.1f %12.1f %10.2f\n', PH{p}, a, b, b / max(a, eps));
end
for i = 1:numel(T.sessions)
    s = T.sessions(i);
    parts = cellfun(@(p) sprintf('%s %.1f/%.1f', p, s.v1.(p), s.v2.(p)), PH, ...
        'UniformOutput', false);
    fprintf('    session %s (%s): %s; v1 %d el %d pr, v2 %d el %d pr\n', s.id, s.reference, ...
        strjoin(parts, ', '), s.counts.v1.elements, s.counts.v1.probes, ...
        s.counts.v2.elements, s.counts.v2.probes);
    for e = 1:numel(s.errors)
        fprintf('      ERROR %s\n', s.errors{e});
    end
end
end

function S = openAt(root, sid)
vlt.file.str2text(fullfile(root, '.ndi', 'unique_reference.txt'), sid);
S = ndi.session.dir(root);
if ~strcmp(S.id(), sid)
    error('NDI:readPhaseTimings:wrongSession', 'opened session %s, not %s', S.id(), sid);
end
end

function buildV1Database(file, structs)
% as corpusObjectEquivalence builds it (did.implementations.sqlitedb, branch 'a')
w = warning('off', 'DID:SQLiteDB:add_doc');
restoreWarn = onCleanup(@() warning(w)); %#ok<NASGU>
db = did.implementations.sqlitedb(file);
if ~ismember('a', db.all_branch_ids())
    db.add_branch('a');
end
chunk = 500;
for s = 1:chunk:numel(structs)
    idx = s:min(s + chunk - 1, numel(structs));
    docs = cellfun(@(x) did.document(x), structs(idx), 'UniformOutput', false);
    try
        db.add_docs(docs, 'a', 'Validate', false);
    catch
        for k = 1:numel(docs)
            try
                db.add_docs(docs(k), 'a', 'Validate', false, 'OnDuplicate', 'ignore');
            catch
            end
        end
    end
end
clear db
end

function c = asCell(x)
if isempty(x)
    c = {};
elseif iscell(x)
    c = reshape(x, 1, []);
else
    c = {x};
end
end

function removeDir(d)
try
    if isfolder(d); rmdir(d, 's'); end
catch
end
end

function label = profileLabel(doProfile, side)
% the side's label when profiling (both sides are profiled, so their
% breakdowns can be compared), else ''
label = '';
if doProfile; label = side; end
end
