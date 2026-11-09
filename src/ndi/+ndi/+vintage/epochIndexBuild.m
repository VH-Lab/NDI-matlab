function report = epochIndexBuild(root)
%EPOCHINDEXBUILD Build the derived epoch-table index of a migrated folder from its documents.
%
%   REPORT = ndi.vintage.epochIndexBuild(ROOT) drops every row of the
%   epoch-table index (ndi.vintage.epochIndex) in the v2 database under
%   ROOT/.ndi and computes it again from the documents: for each session
%   holding an acquisition system, in a freshly opened session
%   (ndi.session.dir with that session id, which reads and adds no session
%   record), each system's navigator reads its ingested epochs and, for an
%   mfdaq or image system, its reader their clocks (what
%   ndi.daq.system/buildepochtable reads of them, without opening any
%   epoch on disk), and they store the rows they compute. Dropping and rebuilding gives the same rows: they
%   are computed only from the documents. REPORT says what was done,
%   denominator first (sessions, systems, epochs, rows).
%
%   ndi.migrate.local and the v2 import call it as their last step (Jess
%   Haley, 2026-11-09, [3 yes]), so the index ships in the database; a read
%   that finds no current row computes and stores it (the lazy fallback).
%   On a database that keeps no derived rows it does nothing.
%
%   See also ndi.vintage.epochIndex.

report = struct('sessions', 0, 'systems', 0, 'epochs', 0, 'elements', 0, 'rows', NaN, 'built', false);
ndiDir = fullfile(char(root), '.ndi');
S0 = [];
sids = {};
try
    dbs = dir(fullfile(ndiDir, '*.sqlite'));
    for k = 1:numel(dbs)
        f = fullfile(dbs(k).folder, dbs(k).name);
        try
            db = did2.database.sqlitedb(f);
        catch
            continue;   % not a v2 database
        end
        c = onCleanup(@() db.close());
        if ~any(strcmp(methods('did2.database.sqlitedb'), 'derivedRowsAvailable'))
            continue;   % a DID-matlab without the derived-row store (a static method: methods() sees it)
        end
        db.derivedClear('ndi.epochs.navigator');
        db.derivedClear('ndi.epochs.reader');
        db.derivedClear('ndi.elements');
        docs = db.search(did2.query('', 'isa', 'acquisition_system'));
        for i = 1:numel(docs)
            sids{end+1} = char(did2.schema.cache.sessionIdOf(docs{i}.toStruct())); %#ok<AGROW>
        end
        clear c;
    end
catch err
    warning('NDI:vintage:epochIndexBuild:notRead', 'The epoch-table index was not built: %s', err.message);
    return;
end
sids = unique(sids(~cellfun(@isempty, sids)), 'stable');
report.sessions = numel(sids);
% Opening a session folder writes .ndi/reference.txt, unique_reference.txt,
% the object-type marker and a session-table entry (ndi.session.dir). The
% index is built from the documents and must leave the folder as it was:
% every small file of .ndi (not the databases) and the session table are
% put back afterwards, even on an error (TestHaleyWrite/testDataset found
% the dataset's reference.txt rewritten, run 42589451455).
restore = onCleanup(snapshotFolder(ndiDir, sids)); %#ok<NASGU>
for i = 1:numel(sids)
    S = ndi.session.dir('epoch index', char(root), sids{i});
    if ~ndi.vintage.epochIndex('available', S)
        continue;
    end
    devs = S.daqsystem_load('name', '(.*)');
    if ~iscell(devs); devs = {devs}; end
    for k = 1:numel(devs)
        dev = devs{k};
        if isempty(dev); continue; end
        % exactly what the index holds, computed as the epoch-table build
        % computes it -- the navigator's ingested epochs and, for an mfdaq
        % or image system, its reader's clocks -- and nothing else: no
        % epoch on disk is opened (a full epoch table reads raw files, such
        % as videos)
        nav = dev.filenavigator;
        cls = nav.epochprobemap_class;
        docs = S.database_search(ndi.vintage.ingestedQuery(nav.id(), S.id()));
        E = ndi.vintage.ingestedEpochs(S, docs, cls);
        if isa(dev, 'ndi.daq.system.mfdaq') || isa(dev, 'ndi.daq.system.image')
            ids = {};
            if ~isempty(E)
                ids = {E(strcmp({E.vintage}, 'V_eta')).epoch_id};
                ids = ids(~cellfun(@isempty, ids));
            end
            if ~isempty(ids)
                ndi.vintage.ingestedArchives(S, dev.daqreader.id(), ids, 'ClocksOnly', true);
            end
        end
        report.systems = report.systems + 1;
        report.epochs = report.epochs + numel(E);
    end
    % the migrated elements' rows (ndi.vintage.prefetchElementFields, as
    % getelements reads them; Jess Haley, 2026-11-09: "Add elements to the
    % derived index")
    els = S.getelements();
    report.elements = report.elements + numel(els);
    S0 = S;
end
if ~isempty(S0)
    report.rows = S0.database_derived('count', 'ndi.epochs.navigator') + ...
        S0.database_derived('count', 'ndi.epochs.reader') + S0.database_derived('count', 'ndi.elements');
end
report.built = true;
end

function f = snapshotFolder(ndiDir, sids)
% a function that puts back the small files of NDIDIR and the session-table
% entries of SIDS as they are now
listing = dir(ndiDir);
keep = struct('name', {}, 'bytes', {});
for k = 1:numel(listing)
    if listing(k).isdir || endsWith(listing(k).name, {'.sqlite', '.sqlite-journal', '.sqlite-wal', '.sqlite-shm'})
        continue;
    end
    fid = fopen(fullfile(ndiDir, listing(k).name), 'r');
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
    keep(end+1) = struct('name', listing(k).name, 'bytes', b); %#ok<AGROW>
end
st = ndi.session.sessiontable();
t0 = st.getsessiontable();
f = @() putBack(ndiDir, keep, sids, t0);
end

function putBack(ndiDir, keep, sids, t0)
listing = dir(ndiDir);
for k = 1:numel(listing)
    n = listing(k).name;
    if listing(k).isdir || endsWith(n, {'.sqlite', '.sqlite-journal', '.sqlite-wal', '.sqlite-shm'})
        continue;
    end
    if ~any(strcmp({keep.name}, n))
        delete(fullfile(ndiDir, n));   % written by the opening
    end
end
for k = 1:numel(keep)
    fid = fopen(fullfile(ndiDir, keep(k).name), 'w');
    fwrite(fid, keep(k).bytes, 'uint8');
    fclose(fid);
end
st = ndi.session.sessiontable();
for i = 1:numel(sids)
    was = find(strcmp({t0.session_id}, sids{i}), 1);
    if isempty(was)
        st.removetableentry(sids{i});
    else
        st.addtableentry(sids{i}, t0(was).path);
    end
end
end
