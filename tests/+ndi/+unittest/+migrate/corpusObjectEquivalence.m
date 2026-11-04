function R = corpusObjectEquivalence(v1Bodies, migratedNdiDir, label, options)
%CORPUSOBJECTEQUIVALENCE The same NDI objects before and after ndi.migrate.local, corpus-wide.
%
%   R = ndi.unittest.migrate.corpusObjectEquivalence(V1BODIES, MIGRATEDNDIDIR, LABEL)
%
%   Object-level equivalence over a whole corpus (VH-Lab/NDI-matlab#785),
%   the corpus-wide counterpart of TestReadTimeseriesEquivalence, which
%   checks one fixture. V1BODIES is the corpus as it was migrated: a cell
%   array of v1 documents as JSON text (what TestMigrateLocalEtaB and
%   TestMigrateLocalEtaDab read from the zip). MIGRATEDNDIDIR is the .ndi
%   folder ndi.migrate.local wrote its did_v2.sqlite into.
%
%   BEFORE. The bodies are added to a real DID v1 database
%   (did.implementations.sqlitedb, branch 'a', the database NDI's v1
%   backend ndi.database.implementations.database.didsqlite opens) in a
%   folder of its own, so each session opens through ndi.session.dir as a
%   v1 session. The e2e tests migrate a minimal `docs` table that NDI's v1
%   backend cannot open, so this database is built for the v1 side only;
%   its documents are the same bodies.
%
%   AFTER. A COPY of MIGRATEDNDIDIR, so that opening a session (which
%   writes reference.txt and unique_reference.txt) and the write round trip
%   change nothing the calling test reads.
%
%   For every session, opened before and after (by its session id):
%     subject        getsubjects: id, local identifier, description (v1
%                    `subject.description`, after migration `notes`)
%     subject fact   every v1 document that depends on a subject
%                    (`subject_id`): after migration, the document with the
%                    same id, or a document pointing at both it and the
%                    subject (a relation), still ties it to that subject
%     element        getelements: id, name, reference, type, class,
%                    subject, underlying element (id and name), direct
%     probe          getprobes, keyed by name | reference | type: id,
%                    subject, class
%     probe epoch    each probe's epoch table, by epoch id: number, clocks,
%                    t0_t1, probe map, underlying epoch ids. The probe map
%                    is compared as what it wires: per probe (name,
%                    reference, type, subject), its channels in row order.
%                    [probe in several rows is one wiring] (Jess Haley,
%                    2026-11-03) merges a probe's rows into one
%                    (`vhvis_spike2:mk1-3;e1-3;md1`); such epochs are
%                    counted, not reported as differences
%     daq system     daqsystem_load, by name: class
%     daq epoch      each acquisition system's epoch table, as above
%     element epoch  each non-probe element's epoch table, as above
%   and once per corpus:
%     write round trip  a v1-writer document (as NDI apps write them,
%                    stored stamped did_v1) and a v2 term assertion added to
%                    a migrated session, the session reopened, both read
%                    back unchanged
%   Apparatus and equipment: a migrated `entity` whose id is no v1 subject
%   has no v1 subject object to compare with. They are counted by type and
%   by what their id was in v1 (an element, another v1 class, or a new id),
%   not compared.
%
%   read_error counts every object read that raised, on either side.
%
%   R = ...(..., 'MaxProbeEpochTables', N) reads the epoch tables of at most
%   N probes per session (evenly spaced over the v1 probes sorted by key; the
%   same probes after migration); every probe is still compared as an
%   object, and every acquisition system's epoch table, probe map included,
%   is still read whole. NDI builds each probe's table from its system's
%   epochs, so the cost is probes times epochs: Dab's one session holds 762
%   probes over 1,604 ingested epochs and did not finish in the workflow's
%   180 minutes reading them all (run 41721521588). The report says how many
%   probe tables were read of how many probes; the rest are not measured.
%
%   Every category reports its denominator first: how many were compared,
%   how many were the same, how many differed, and how many were found on
%   one side only. Every read is taken inside try/catch; an error is a
%   difference of kind "error", never a silent zero.
%
%   t0_t1 is compared to 1e-9 s, relative above 1 s: migration writes an
%   epoch's extent as a start and a duration on its time references
%   ([clock only on the time reference]), and start + duration is not
%   always the v1 end to the bit.

arguments
    v1Bodies cell
    migratedNdiDir {mustBeTextScalar}
    label {mustBeTextScalar} = 'corpus'
    options.MaxProbeEpochTables (1,1) double = Inf
end

label = char(label);
migratedNdiDir = char(migratedNdiDir);
R = struct('label', label, 'sessions', struct(), 'v1db', struct(), ...
    'probeTables', struct('read', 0, 'probes', 0, 'cap', options.MaxProbeEpochTables), ...
    'apparatus', struct(), 'cats', struct(), 'seconds', struct());
for c = categoryNames()
    R.cats.(c{1}) = newCat();
end

% ---- the v1 side ---------------------------------------------------------
t = tic;
v1Structs = cell(1, numel(v1Bodies));
for k = 1:numel(v1Bodies)
    v1Structs{k} = jsondecode(char(v1Bodies{k}));
end
R.seconds.decode = toc(t);

v1Root = tempname();
mkdir(fullfile(v1Root, '.ndi'));
cleanV1 = onCleanup(@() removeDir(v1Root));
t = tic;
R.v1db = buildV1Database(fullfile(v1Root, '.ndi', 'did-sqlite.sqlite'), v1Structs);
R.seconds.v1database = toc(t);
fprintf('\n  [%s equivalence] v1 database: %d of %d document(s) added, %d refused, %.1f s\n', ...
    label, R.v1db.added, R.v1db.read, R.v1db.refused, R.seconds.v1database);

% ---- the v2 side (a copy) ------------------------------------------------
v2Root = tempname();
mkdir(v2Root);
cleanV2 = onCleanup(@() removeDir(v2Root));
copyfile(migratedNdiDir, fullfile(v2Root, '.ndi'));
for f = {'unique_reference.txt', 'reference.txt', '.migrate.lock'}
    p = fullfile(v2Root, '.ndi', f{1});
    if isfile(p); delete(p); end
end
dstFile = ndi.database.implementations.database.did2sqlite.FILEIN(fullfile(v2Root, '.ndi'));
t = tic;
v2Structs = readDid2Bodies(dstFile);
R.seconds.v2read = toc(t);

% ---- ids, by side --------------------------------------------------------
v1ById = idMap(v1Structs);
v2ById = idMap(v2Structs);
v1Subjects = classIds(v1Structs, 'subject');
v1Elements = classIds(v1Structs, 'element');

% ---- sessions ------------------------------------------------------------
v1Sids = v1SessionIds(v1Structs);
v2Sids = v2SessionIds(v2Structs);
both = intersect(v1Sids, v2Sids, 'stable');
R.sessions = struct('v1', numel(v1Sids), 'v2', numel(v2Sids), ...
    'compared', 0, 'only_v1', {setdiff(v1Sids, v2Sids)}, ...
    'only_v2', {setdiff(v2Sids, v1Sids)}, 'errors', {{}});
fprintf('  [%s equivalence] sessions: %d in v1, %d after migration, %d in both\n', ...
    label, numel(v1Sids), numel(v2Sids), numel(both));

t = tic;
for i = 1:numel(both)
    sid = both{i};
    [S1, e1] = openAt(v1Root, sid, 'ndi.database.implementations.database.didsqlite');
    [S2, e2] = openAt(v2Root, sid, 'ndi.database.implementations.database.did2sqlite');
    if ~isempty(e1) || ~isempty(e2)
        R.sessions.errors{end+1} = sprintf('session %s: v1 open: %s | migrated open: %s', ...
            sid, e1, e2);
        continue;
    end
    R.sessions.compared = R.sessions.compared + 1;
    ts = tic;
    a = snapshot(S1, options.MaxProbeEpochTables, {}, false);
    b = snapshot(S2, Inf, a.probeEpochKeys, true);
    R.probeTables.read = R.probeTables.read + numel(a.probeEpochKeys);
    R.probeTables.probes = R.probeTables.probes + numel(a.probes);
    clear S1 S2
    R.cats = compareSnapshots(R.cats, a, b, sid);
    fprintf('    session %s (%s): %d/%d subject(s), %d/%d element(s), %d/%d probe(s), %d/%d daq system(s), %.1f s\n', ...
        sid, a.reference, numel(a.subjects), numel(b.subjects), numel(a.elements), ...
        numel(b.elements), numel(a.probes), numel(b.probes), numel(a.daq), ...
        numel(b.daq), toc(ts));
end
R.seconds.sessions = toc(t);

% ---- subject facts (document level, every session) -----------------------
R.cats.subject_fact = compareFacts(R.cats.subject_fact, v1Structs, v1Subjects, v2ById, v2Structs);

% ---- apparatus and equipment: counted, not compared ----------------------
R.apparatus = countApparatus(v2Structs, v1Subjects, v1Elements, v1ById);

% ---- write round trip on the migrated copy -------------------------------
if ~isempty(both)
    R.cats.write_round_trip = writeRoundTrip(R.cats.write_round_trip, v2Root, both{1});
end

printReport(R);
end

% =========================================================================
% categories
% =========================================================================

function names = categoryNames()
names = {'read_error', 'subject', 'subject_fact', 'element', 'probe', 'probe_epoch', ...
    'daq_system', 'daq_epoch', 'element_epoch', 'write_round_trip'};
end

function C = newCat()
C = struct('compared', 0, 'same', 0, 'differ', 0, 'only_v1', 0, 'only_v2', 0, ...
    'merged_probemap_rows', 0, ...
    'kinds', {{}}, 'kindCounts', [], 'examples', {{}});
end

function C = tally(C, outcome, kind, msg)
% OUTCOME is 'same', 'differ', 'only_v1' or 'only_v2'. A pair found on both
% sides is "compared"; a one-sided one is not.
switch outcome
    case 'same'
        C.compared = C.compared + 1;
        C.same = C.same + 1;
        return;
    case 'differ'
        C.compared = C.compared + 1;
        C.differ = C.differ + 1;
    case 'only_v1'
        C.only_v1 = C.only_v1 + 1;
    case 'only_v2'
        C.only_v2 = C.only_v2 + 1;
end
kind = [outcome ': ' kind];
k = find(strcmp(C.kinds, kind), 1);
if isempty(k)
    C.kinds{end+1} = kind;
    C.kindCounts(end+1) = 0;
    C.examples{end+1} = {};
    k = numel(C.kinds);
end
C.kindCounts(k) = C.kindCounts(k) + 1;
if numel(C.examples{k}) < 5
    C.examples{k}{end+1} = msg;
end
end

% =========================================================================
% the v1 database
% =========================================================================

function info = buildV1Database(file, structs)
% A DID v1 sqlite database on branch 'a' holding STRUCTS, added through
% did.database/add_docs as NDI's v1 backend adds them. Files named in a
% document are not on disk (the corpus zips are document-only), so their
% "failed to cache" warnings are switched off while adding.
info = struct('read', numel(structs), 'added', 0, 'refused', 0, 'refusals', {{}});
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
        info.added = info.added + numel(idx);
    catch
        % one at a time, so one refused document does not cost its chunk
        for k = 1:numel(docs)
            try
                db.add_docs(docs(k), 'a', 'Validate', false, 'OnDuplicate', 'ignore');
                info.added = info.added + 1;
            catch ME
                info.refused = info.refused + 1;
                if numel(info.refusals) < 10
                    info.refusals{end+1} = sprintf('%s %s: %s', ...
                        className(structs{idx(k)}), docId(structs{idx(k)}), ME.message);
                end
            end
        end
    end
end
clear db
end

function bodies = readDid2Bodies(file)
db = did2.database.sqlitedb(file);
closer = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

% =========================================================================
% sessions
% =========================================================================

function [S, err] = openAt(root, sid, expectedDb)
S = [];
err = '';
try
    vlt.file.str2text(fullfile(root, '.ndi', 'unique_reference.txt'), sid);
    S = ndi.session.dir(root);
    if ~strcmp(S.id(), sid)
        err = sprintf('opened session %s, not %s', S.id(), sid);
        S = [];
        return;
    end
    db = ndi.database.fun.opendatabase(fullfile(root, '.ndi'), sid);
    if ~isa(db, expectedDb)
        err = sprintf('the session opened a %s, not a %s', class(db), expectedDb);
        S = [];
    end
catch ME
    err = errorText(ME);
    S = [];
end
end

function sids = v1SessionIds(structs)
sids = {};
for k = 1:numel(structs)
    b = structs{k};
    if strcmp(className(b), 'session') && isfield(b, 'base') && isfield(b.base, 'session_id')
        sids{end+1} = char(b.base.session_id); %#ok<AGROW>
    end
end
sids = unique(sids, 'stable');
end

function sids = v2SessionIds(structs)
sids = {};
for k = 1:numel(structs)
    b = structs{k};
    cn = className(b);
    if strcmp(cn, 'entity') && isfield(b, 'entity') && isfield(b.entity, 'type') ...
            && any(ndi.v2.vocabIs('entity_type', b.entity.type, {'session', 'dataset'}))
        sids{end+1} = char(b.base.id); %#ok<AGROW>
    elseif strcmp(cn, 'session') && isfield(b, 'base') && isfield(b.base, 'session_id')
        sids{end+1} = char(b.base.session_id); %#ok<AGROW>
    end
end
sids = unique(sids, 'stable');
end

% =========================================================================
% one session's objects, as plain data
% =========================================================================

function s = snapshot(S, cap, onlyKeys, restrict)
% CAP: the most probe epoch tables to read; RESTRICT: read only ONLYKEYS'
s = struct('reference', '', 'subjects', {{}}, 'elements', {{}}, 'probes', {{}}, ...
    'daq', {{}}, 'errors', {{}}, 'probeEpochKeys', {{}});
try
    s.reference = char(S.reference);
catch ME
    s.errors{end+1} = ['reference: ' errorText(ME)];
end

% subjects
try
    docs = asCell(S.getsubjects());
    for k = 1:numel(docs)
        p = ndi.v2.props(docs{k});
        desc = ndi.v2.blockOf(p, 'subject', 'description', '');
        if isempty(desc)
            desc = ndi.v2.blockOf(p, 'subject', 'notes', '');
        end
        s.subjects{end+1} = struct('key', char(p.base.id), 'id', char(p.base.id), ...
            'local_identifier', char(ndi.v2.blockOf(p, 'subject', 'local_identifier', '')), ...
            'description', char(desc)); %#ok<AGROW>
    end
catch ME
    s.errors{end+1} = ['getsubjects: ' errorText(ME)];
end

% elements (probes included: a probe is an element), and their epochs
try
    els = uniqueById(asCell(S.getelements()));
    for k = 1:numel(els)
        o = els{k};
        e = elementFacts(o);
        e.key = e.id;
        e.epochs = [];
        e.epochError = '';
        if ~isa(o, 'ndi.probe')
            try
                e.epochs = normalizeEpochTable(o.epochtable());
            catch ME
                e.epochError = errorText(ME);
            end
        end
        s.elements{end+1} = e; %#ok<AGROW>
    end
catch ME
    s.errors{end+1} = ['getelements: ' errorText(ME)];
end

% probes, and their epoch tables
try
    prs = uniqueById(asCell(S.getprobes()));
    keys = cell(1, numel(prs));
    for k = 1:numel(prs)
        e = elementFacts(prs{k});
        keys{k} = sprintf('%s | %s | %s', e.name, num2str(e.reference), e.type);
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
        o = prs{k};
        e = elementFacts(o);
        e.key = keys{k};
        e.epochs = [];
        e.epochError = '';
        e.epochRead = any(strcmp(toRead, e.key));
        if e.epochRead
            try
                e.epochs = normalizeEpochTable(o.epochtable());
            catch ME
                e.epochError = errorText(ME);
            end
            s.probeEpochKeys{end+1} = e.key; %#ok<AGROW>
        end
        s.probes{end+1} = e; %#ok<AGROW>
    end
catch ME
    s.errors{end+1} = ['getprobes: ' errorText(ME)];
end

% acquisition systems, and their epoch tables
try
    devs = asCell(S.daqsystem_load('name', '(.*)'));
    for k = 1:numel(devs)
        d = devs{k};
        e = struct('key', char(d.name), 'name', char(d.name), 'class', class(d), ...
            'epochs', [], 'epochError', '');
        try
            e.epochs = normalizeEpochTable(d.epochtable());
        catch ME
            e.epochError = errorText(ME);
        end
        s.daq{end+1} = e; %#ok<AGROW>
    end
catch ME
    s.errors{end+1} = ['daqsystem_load: ' errorText(ME)];
end
end

function e = elementFacts(o)
e = struct('id', '', 'name', '', 'reference', [], 'type', '', 'class', class(o), ...
    'subject_id', '', 'underlying_id', '', 'underlying_name', '', 'direct', []);
e.id = char(o.id());
e.name = char(o.name);
e.reference = double(o.reference);
e.type = char(o.type);
e.subject_id = char(o.subject_id);
e.direct = logical(o.direct);
u = o.underlying_element;
if ~isempty(u)
    e.underlying_id = char(u.id());
    e.underlying_name = char(u.name);
end
end

function n = normalizeEpochTable(et)
% The epoch table as plain data (as TestReadTimeseriesEquivalence
% normalizes it), tolerant of an epoch whose probe map is empty or is not
% an ndi.epoch.epochprobemap: those are kept as their class name.
n = struct('epoch_number', {}, 'epoch_id', {}, 'epoch_session_id', {}, ...
    'epoch_clock', {}, 't0_t1', {}, 'epochprobemap', {}, 'underlying_epoch_ids', {});
for i = 1:numel(et)
    e = et(i);
    n(i).epoch_number = double(e.epoch_number);
    n(i).epoch_id = char(e.epoch_id);
    n(i).epoch_session_id = '';
    if isfield(e, 'epoch_session_id')
        n(i).epoch_session_id = char(e.epoch_session_id);
    end
    n(i).epoch_clock = cellfun(@(c) c.ndi_clocktype2char(), asCell(e.epoch_clock), ...
        'UniformOutput', false);
    n(i).t0_t1 = cellfun(@(x) double(x(:)'), asCell(e.t0_t1), 'UniformOutput', false);
    n(i).epochprobemap = probemapRows(e.epochprobemap);
    ue = {};
    if isfield(e, 'underlying_epochs')
        for k = 1:numel(e.underlying_epochs)
            ue{end+1} = char(e.underlying_epochs(k).epoch_id); %#ok<AGROW>
        end
    end
    n(i).underlying_epoch_ids = ue;
end
end

function pm = probemapRows(m)
pm = {};
for k = 1:numel(m)
    if iscell(m); p = m{k}; else; p = m(k); end
    try
        pm{end+1} = struct('name', char(p.name), 'reference', double(p.reference), ...
            'type', char(p.type), 'devicestring', char(p.devicestring), ...
            'subjectstring', char(p.subjectstring)); %#ok<AGROW>
    catch
        pm{end+1} = struct('class', class(p)); %#ok<AGROW>
    end
end
end

% =========================================================================
% comparison
% =========================================================================

function cats = compareSnapshots(cats, a, b, sid)
for k = 1:numel(a.errors)
    cats.read_error = tally(cats.read_error, 'only_v1', 'a v1 read raised', ...
        sprintf('session %s: %s', sid, a.errors{k}));
end
for k = 1:numel(b.errors)
    cats.read_error = tally(cats.read_error, 'only_v2', 'a read of the migrated session raised', ...
        sprintf('session %s: %s', sid, b.errors{k}));
end

cats.subject = comparePairs(cats.subject, a.subjects, b.subjects, ...
    {'local_identifier', 'description'}, sid, 'subject');
cats.element = comparePairs(cats.element, a.elements, b.elements, ...
    {'name', 'reference', 'type', 'class', 'subject_id', 'underlying_id', ...
     'underlying_name', 'direct'}, sid, 'element');
cats.probe = comparePairs(cats.probe, a.probes, b.probes, ...
    {'id', 'class', 'subject_id', 'underlying_id', 'direct'}, sid, 'probe');
cats.daq_system = comparePairs(cats.daq_system, a.daq, b.daq, {'class'}, sid, 'daq system');

cats.probe_epoch = compareEpochsOf(cats.probe_epoch, a.probes, b.probes, sid, 'probe');
cats.daq_epoch = compareEpochsOf(cats.daq_epoch, a.daq, b.daq, sid, 'daq system');
ea = a.elements(cellfun(@(e) ~strcmp(e.class, 'ndi.probe') && ~isProbeClass(e.class), a.elements));
eb = b.elements(cellfun(@(e) ~strcmp(e.class, 'ndi.probe') && ~isProbeClass(e.class), b.elements));
cats.element_epoch = compareEpochsOf(cats.element_epoch, ea, eb, sid, 'element');
end

function tf = isProbeClass(c)
tf = false;
try
    tf = any(strcmp('ndi.probe', superclasses(c)));
catch
end
end

function C = comparePairs(C, A, B, fields, sid, what)
ka = cellfun(@(x) x.key, A, 'UniformOutput', false);
kb = cellfun(@(x) x.key, B, 'UniformOutput', false);
for i = 1:numel(A)
    j = find(strcmp(kb, ka{i}), 1);
    if isempty(j)
        C = tally(C, 'only_v1', [what ' not found after migration'], ...
            sprintf('session %s: %s %s', sid, what, describeObj(A{i})));
        continue;
    end
    bad = {};
    for f = fields
        va = A{i}.(f{1});
        vb = B{j}.(f{1});
        if ~isequal(va, vb)
            bad{end+1} = f{1}; %#ok<AGROW>
            C = tally(C, 'differ', sprintf('%s.%s', what, f{1}), ...
                sprintf('session %s: %s %s: %s v1 %s, migrated %s', sid, what, ...
                ka{i}, f{1}, show(va), show(vb)));
        end
    end
    if isempty(bad)
        C = tally(C, 'same', '', '');
    else
        % tally counted one "compared" per differing field; keep one per pair
        C.compared = C.compared - (numel(bad) - 1);
        C.differ = C.differ - (numel(bad) - 1);
    end
end
for j = 1:numel(B)
    if ~any(strcmp(ka, kb{j}))
        C = tally(C, 'only_v2', [what ' with no v1 counterpart'], ...
            sprintf('session %s: %s %s', sid, what, describeObj(B{j})));
    end
end
end

function C = compareEpochsOf(C, A, B, sid, what)
% the epoch tables of the objects found on both sides, epoch by epoch
kb = cellfun(@(x) x.key, B, 'UniformOutput', false);
for i = 1:numel(A)
    j = find(strcmp(kb, A{i}.key), 1);
    if isempty(j); continue; end
    if (isfield(A{i}, 'epochRead') && ~A{i}.epochRead) || ...
            (isfield(B{j}, 'epochRead') && ~B{j}.epochRead)
        continue;   % not read (MaxProbeEpochTables): not measured
    end
    if ~isempty(A{i}.epochError) || ~isempty(B{j}.epochError)
        C = tally(C, 'differ', [what ' epochtable error'], sprintf( ...
            'session %s: %s %s: v1 %s | migrated %s', sid, what, A{i}.key, ...
            A{i}.epochError, B{j}.epochError));
        continue;
    end
    C = compareEpochTables(C, A{i}.epochs, B{j}.epochs, ...
        sprintf('session %s: %s %s', sid, what, A{i}.key));
end
end

function C = compareEpochTables(C, ea, eb, where)
ida = arrayfun(@(e) e.epoch_id, ea, 'UniformOutput', false);
idb = arrayfun(@(e) e.epoch_id, eb, 'UniformOutput', false);
for i = 1:numel(ea)
    j = find(strcmp(idb, ida{i}), 1);
    if isempty(j)
        C = tally(C, 'only_v1', 'epoch not found after migration', ...
            sprintf('%s: epoch %s', where, ida{i}));
        continue;
    end
    a = ea(i);
    b = eb(j);
    bad = {};
    if ~isequal(a.epoch_number, b.epoch_number); bad{end+1} = 'epoch_number'; end %#ok<AGROW>
    if ~isequal(a.epoch_session_id, b.epoch_session_id); bad{end+1} = 'epoch_session_id'; end %#ok<AGROW>
    if ~isequal(a.epoch_clock, b.epoch_clock); bad{end+1} = 'epoch_clock'; end %#ok<AGROW>
    if ~sameT0T1(a.t0_t1, b.t0_t1); bad{end+1} = 't0_t1'; end %#ok<AGROW>
    if ~isequal(probemapWiring(a.epochprobemap), probemapWiring(b.epochprobemap))
        bad{end+1} = 'epochprobemap'; %#ok<AGROW>
    elseif ~isequal(a.epochprobemap, b.epochprobemap)
        % the same probes on the same channels, written in fewer rows:
        % [probe in several rows is one wiring] (Jess Haley, 2026-11-03)
        % merges a probe's rows into one (`...:mk1-3;e1-3;md1`). Counted,
        % not a difference.
        C.merged_probemap_rows = C.merged_probemap_rows + 1;
    end
    if ~isequal(sort(a.underlying_epoch_ids), sort(b.underlying_epoch_ids))
        bad{end+1} = 'underlying_epoch_ids'; %#ok<AGROW>
    end
    if isempty(bad)
        C = tally(C, 'same', '', '');
        continue;
    end
    C = tally(C, 'differ', ['epoch ' strjoin(bad, ', ')], sprintf( ...
        '%s: epoch %s: %s', where, ida{i}, epochDiffText(a, b, bad)));
end
for j = 1:numel(eb)
    if ~any(strcmp(ida, idb{j}))
        C = tally(C, 'only_v2', 'epoch with no v1 counterpart', ...
            sprintf('%s: epoch %s', where, idb{j}));
    end
end
end

function W = probemapWiring(pm)
% A probe map as what it wires: per probe (name, reference, type, subject),
% the ordered list of `system:channel` its rows name, rows taken in order.
% Two maps that wire the same probes to the same channels in the same order
% give the same W, however the rows are split.
keys = {};
chans = {};
for k = 1:numel(pm)
    r = pm{k};
    if ~isfield(r, 'name')
        key = jsonencode(r);
        list = {};
    else
        key = sprintf('%s|%g|%s|%s', r.name, r.reference, r.type, r.subjectstring);
        list = expandDeviceString(r.devicestring);
    end
    i = find(strcmp(keys, key), 1);
    if isempty(i)
        keys{end+1} = key; %#ok<AGROW>
        chans{end+1} = list; %#ok<AGROW>
    else
        chans{i} = [chans{i}, list];
    end
end
[keys, o] = sort(keys);
W = struct('probe', keys, 'channels', chans(o));
end

function list = expandDeviceString(ds)
% 'sys:mk1-3;e1,4;md1' -> {'sys:mk1','sys:mk2','sys:mk3','sys:e1','sys:e4','sys:md1'}
list = {};
ds = char(ds);
c = find(ds == ':', 1);
if isempty(c)
    list = {ds};
    return;
end
sys = ds(1:c-1);
for seg = strsplit(ds(c+1:end), ';')
    t = regexp(strtrim(seg{1}), '^([A-Za-z_]+)(.*)$', 'tokens', 'once');
    if isempty(t)
        if ~isempty(strtrim(seg{1})); list{end+1} = [sys ':' strtrim(seg{1})]; end %#ok<AGROW>
        continue;
    end
    nums = [];
    for part = strsplit(t{2}, ',')
        ab = sscanf(part{1}, '%d-%d');
        if numel(ab) == 2
            nums = [nums, ab(1):ab(2)]; %#ok<AGROW>
        elseif numel(ab) == 1
            nums(end+1) = ab; %#ok<AGROW>
        end
    end
    if isempty(nums)
        list{end+1} = [sys ':' t{1}]; %#ok<AGROW>
    end
    for n = nums
        list{end+1} = sprintf('%s:%s%d', sys, t{1}, n); %#ok<AGROW>
    end
end
end

function tf = sameT0T1(a, b)
tf = isequal(size(a), size(b));
if ~tf; return; end
for k = 1:numel(a)
    x = a{k};
    y = b{k};
    if ~isequal(size(x), size(y)) || any(isnan(x) ~= isnan(y))
        tf = false;
        return;
    end
    ok = ~isnan(x);
    tol = 1e-9 * max(1, abs(x(ok)));
    if any(abs(x(ok) - y(ok)) > tol)
        tf = false;
        return;
    end
end
end

function s = epochDiffText(a, b, bad)
parts = {};
for k = 1:numel(bad)
    parts{end+1} = sprintf('%s v1 %s, migrated %s', bad{k}, show(a.(bad{k})), ...
        show(b.(bad{k}))); %#ok<AGROW>
end
s = strjoin(parts, '; ');
end

% =========================================================================
% subject facts, apparatus, write round trip
% =========================================================================

function C = compareFacts(C, v1Structs, v1Subjects, v2ById, v2Structs)
% A v1 document that depends on a subject (`subject_id`) is a fact about it.
% After migration the fact holds when the document with the same id points
% at that subject, or a document that points at both (a relation, e.g. a
% probe's subject: an element's subject became a relation) does.
refsTo = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(v2Structs)
    e = unique(depValues(v2Structs{k}, ''));
    for m = 1:numel(e)
        if isKey(refsTo, e{m})
            refsTo(e{m}) = [refsTo(e{m}), k];
        else
            refsTo(e{m}) = k;
        end
    end
end
for k = 1:numel(v1Structs)
    b = v1Structs{k};
    subj = intersect(depValues(b, 'subject_id'), v1Subjects);
    if isempty(subj); continue; end
    cn = className(b);
    id = docId(b);
    if ~isKey(v2ById, id)
        C = tally(C, 'only_v1', sprintf('%s: no document with its id after migration', cn), ...
            sprintf('%s %s (subject %s)', cn, id, subj{1}));
        continue;
    end
    after = v2ById(id);
    held = ismember(subj, depValues(after, ''));
    if ~all(held) && isKey(refsTo, id)
        for r = refsTo(id)
            held = held | ismember(subj, depValues(v2Structs{r}, ''));
        end
    end
    if all(held)
        C = tally(C, 'same', '', '');
    else
        C = tally(C, 'differ', sprintf('%s: nothing ties it to its subject', cn), ...
            sprintf('%s %s: v1 subject %s; migrated %s edges %s', cn, id, ...
            strjoin(subj, ','), className(after), strjoin(depValues(after, ''), ',')));
    end
end
end

function A = countApparatus(v2Structs, v1Subjects, v1Elements, v1ById)
% The migrated entities that are not a v1 subject, by type and by what
% their id was in v1. There is no v1 subject object to compare them with.
A = struct('entities', 0, 'v1_subject', 0, 'rows', {{}});
keys = {};
counts = [];
for k = 1:numel(v2Structs)
    b = v2Structs{k};
    if ~strcmp(className(b), 'entity'); continue; end
    A.entities = A.entities + 1;
    id = docId(b);
    if ismember(id, v1Subjects)
        A.v1_subject = A.v1_subject + 1;
        continue;
    end
    tname = '';
    if isfield(b, 'entity') && isfield(b.entity, 'type') && isstruct(b.entity.type) ...
            && isfield(b.entity.type, 'name')
        tname = char(b.entity.type.name);
    end
    if ismember(id, v1Elements)
        was = 'a v1 element';
    elseif isKey(v1ById, id)
        was = ['a v1 ' className(v1ById(id))];
    else
        was = 'a new id';
    end
    key = sprintf('type "%s", id was %s', tname, was);
    i = find(strcmp(keys, key), 1);
    if isempty(i)
        keys{end+1} = key; %#ok<AGROW>
        counts(end+1) = 0; %#ok<AGROW>
        i = numel(keys);
    end
    counts(i) = counts(i) + 1;
end
[counts, o] = sort(counts, 'descend');
keys = keys(o);
for i = 1:numel(keys)
    A.rows{end+1} = sprintf('%6d  %s', counts(i), keys{i});
end
end

function C = writeRoundTrip(C, root, sid)
% A document added to the migrated session, the session reopened, the
% document read back: one a v1 writer makes (NDI's apps; stored stamped
% did_v1) and one v2 term assertion on the session.
v1doc = [];
v2doc = [];
try
    S = openOrError(root, sid);
    v1doc = ndi.document('sorting_parameters', 'base.name', 'corpus equivalence round trip', ...
        'base.session_id', S.id());
    S.database_add(v1doc);
    prev = did2.schema.cache.strictMode('TermRegistry', false);
    restore = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev)); %#ok<NASGU>
    v2body = did2.build.statement('assertion', sid, did2.build.term('', 'short name'), ...
        did2.build.term('', 'corpus equivalence round trip'), 'SessionId', sid, ...
        'ValueKind', 'term');
    v2doc = ndi.document(v2body);
    S.database_add(v2doc);
    clear S
catch ME
    C = tally(C, 'differ', 'error writing', errorText(ME));
    return;
end
try
    S = openOrError(root, sid);
    got = S.database_search(ndi.query('base.id', 'exact_string', v1doc.id(), ''));
    if numel(got) == 1 && isequal(got{1}.document_properties.sorting_parameters, ...
            v1doc.document_properties.sorting_parameters) ...
            && strcmp(got{1}.document_properties.base.name, 'corpus equivalence round trip')
        C = tally(C, 'same', '', '');
    else
        C = tally(C, 'differ', 'v1-writer document not read back unchanged', ...
            sprintf('found %d document(s) with id %s', numel(got), v1doc.id()));
    end
    got = S.database_search(ndi.query('base.id', 'exact_string', v2doc.id(), ''));
    if numel(got) ~= 1
        C = tally(C, 'differ', 'v2 assertion not read back', ...
            sprintf('found %d document(s) with id %s', numel(got), v2doc.id()));
    else
        % The class and every value block the same, and every edge written
        % read back with its value. The read pads a V_eta body's class
        % blocks and declared edges (ndi.database.internal.
        % applyReadNormalization), so `base`, `document_class` and
        % `depends_on` are compared by what was written, not whole.
        w = v2doc.document_properties;
        g = got{1}.document_properties;
        bad = {};
        for f = reshape(setdiff(fieldnames(w), {'base', 'document_class', 'depends_on'}), 1, [])
            if ~isfield(g, f{1}) || ~isequaln(g.(f{1}), w.(f{1}))
                bad{end+1} = f{1}; %#ok<AGROW>
            end
        end
        if ~strcmp(className(g), className(w))
            bad{end+1} = 'document_class.class_name';
        end
        if ~all(ismember(depValues(w, ''), depValues(g, '')))
            bad{end+1} = 'depends_on';
        end
        if isempty(bad)
            C = tally(C, 'same', '', '');
        else
            C = tally(C, 'differ', 'v2 assertion not read back unchanged', ...
                sprintf('id %s: %s differ', v2doc.id(), strjoin(bad, ', ')));
        end
    end
catch ME
    C = tally(C, 'differ', 'error reading back', errorText(ME));
end
end

function S = openOrError(root, sid)
[S, err] = openAt(root, sid, 'ndi.database.implementations.database.did2sqlite');
if ~isempty(err)
    error('ndi:unittest:corpusEquivalence:open', '%s', err);
end
end

% =========================================================================
% report
% =========================================================================

function printReport(R)
fprintf('\n  OBJECT EQUIVALENCE BEFORE AND AFTER MIGRATION (%s)\n', R.label);
fprintf(['    DENOMINATOR: %d v1 document(s) read, %d added to the v1 database ' ...
    '(%d refused); sessions: %d v1, %d migrated, %d compared, %d failed to open\n'], ...
    R.v1db.read, R.v1db.added, R.v1db.refused, R.sessions.v1, R.sessions.v2, ...
    R.sessions.compared, numel(R.sessions.errors));
for k = 1:numel(R.v1db.refusals)
    fprintf('      v1 database refused: %s\n', R.v1db.refusals{k});
end
for k = 1:numel(R.sessions.only_v1)
    fprintf('      session only in v1: %s\n', R.sessions.only_v1{k});
end
for k = 1:numel(R.sessions.only_v2)
    fprintf('      session only after migration: %s\n', R.sessions.only_v2{k});
end
for k = 1:numel(R.sessions.errors)
    fprintf('      %s\n', R.sessions.errors{k});
end
fprintf('    %-17s %9s %9s %9s %9s %9s\n', 'category', 'compared', 'same', ...
    'differ', 'only v1', 'only v2');
for c = categoryNames()
    C = R.cats.(c{1});
    fprintf('    %-17s %9d %9d %9d %9d %9d\n', c{1}, C.compared, C.same, C.differ, ...
        C.only_v1, C.only_v2);
end
fprintf('    probe epoch tables read: %d of %d probe(s) (cap per session %g); the rest NOT MEASURED\n', ...
    R.probeTables.read, R.probeTables.probes, R.probeTables.cap);
for c = {'probe_epoch', 'daq_epoch', 'element_epoch'}
    if R.cats.(c{1}).merged_probemap_rows > 0
        fprintf(['      %s: %d epoch(s) wire the same probes to the same channels in ' ...
            'fewer probe-map rows ([probe in several rows is one wiring]); not a difference\n'], ...
            c{1}, R.cats.(c{1}).merged_probemap_rows);
    end
end
for c = categoryNames()
    C = R.cats.(c{1});
    for k = 1:numel(C.kinds)
        fprintf('      %s / %s: %d\n', c{1}, C.kinds{k}, C.kindCounts(k));
        for m = 1:numel(C.examples{k})
            fprintf('          e.g. %s\n', C.examples{k}{m});
        end
    end
end
fprintf(['    APPARATUS AND EQUIPMENT (counted, not compared: no v1 subject object): ' ...
    '%d migrated entit(ies), %d of them v1 subjects; the rest:\n'], ...
    R.apparatus.entities, R.apparatus.v1_subject);
if isempty(R.apparatus.rows)
    fprintf('      (none)\n');
end
for k = 1:numel(R.apparatus.rows)
    fprintf('      %s\n', R.apparatus.rows{k});
end
end

% =========================================================================
% small helpers
% =========================================================================

function M = idMap(structs)
M = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(structs)
    id = docId(structs{k});
    if ~isempty(id)
        M(id) = structs{k};
    end
end
end

function ids = classIds(structs, cn)
ids = {};
for k = 1:numel(structs)
    if strcmp(className(structs{k}), cn)
        ids{end+1} = docId(structs{k}); %#ok<AGROW>
    end
end
end

function cn = className(b)
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function id = docId(b)
id = '';
if isstruct(b) && isfield(b, 'base') && isfield(b.base, 'id')
    id = char(b.base.id);
end
end

function v = depValues(b, name)
% the ids on B's depends_on edges named NAME ('' for every edge)
v = {};
if ~isstruct(b) || ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
d = b.depends_on;
if iscell(d); items = d; else; items = num2cell(d); end
for k = 1:numel(items)
    dk = items{k};
    if ~isstruct(dk); continue; end
    if ~isempty(name) && ~(isfield(dk, 'name') && strcmp(dk.name, name)); continue; end
    x = '';
    if isfield(dk, 'value') && ~isempty(dk.value)
        x = dk.value;
    elseif isfield(dk, 'document_id') && ~isempty(dk.document_id)
        x = dk.document_id;
    end
    if iscell(x)
        v = [v, cellfun(@char, x(:)', 'UniformOutput', false)]; %#ok<AGROW>
    elseif ~isempty(x)
        v{end+1} = char(x); %#ok<AGROW>
    end
end
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

function c = uniqueById(c)
ids = cellfun(@(o) char(o.id()), c, 'UniformOutput', false);
[~, u] = unique(ids, 'stable');
c = c(sort(u));
end

function s = describeObj(x)
s = x.key;
if isfield(x, 'name') && ~strcmp(x.key, x.name)
    s = sprintf('%s (%s)', x.key, x.name);
end
if isfield(x, 'class')
    s = sprintf('%s [%s]', s, x.class);
end
if isfield(x, 'local_identifier')
    s = sprintf('%s "%s"', s, x.local_identifier);
end
end

function s = show(v)
try
    if ischar(v) || isstring(v)
        s = ['"' char(v) '"'];
    elseif isnumeric(v) || islogical(v)
        s = mat2str(v, 17);
    else
        s = jsonencode(v);
    end
catch
    s = sprintf('<%s>', class(v));
end
if numel(s) > 300
    s = [s(1:300) '...'];
end
end

function s = errorText(ME)
s = sprintf('%s (%s)', ME.message, ME.identifier);
if ~isempty(ME.stack)
    s = sprintf('%s at %s line %d', s, ME.stack(1).name, ME.stack(1).line);
end
end

function removeDir(d)
try
    if isfolder(d); rmdir(d, 's'); end
catch
end
end
