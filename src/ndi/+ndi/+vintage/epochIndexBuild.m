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

report = struct('sessions', 0, 'systems', 0, 'epochs', 0, 'rows', NaN, 'built', false);
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
    S0 = S;
end
if ~isempty(S0)
    report.rows = S0.database_derived('count', 'ndi.epochs.navigator') + ...
        S0.database_derived('count', 'ndi.epochs.reader');
end
report.built = true;
end
