function stats = writeDocuments(dbFile, docs, options)
%WRITEDOCUMENTS Write V2 document structs into a did2 database in batches.
%
%   STATS = ndi.setup.V2.writeDocuments(DBFILE, DOCS) adds DOCS (a cell of
%   document structs, as built by did2.build) to the did2 sqlite database
%   DBFILE, BatchSize documents at a time. Each batch is one did2
%   sqlitedb.add: its ingested files are copied, then its documents are
%   inserted in one transaction and committed, so the database and the files
%   folder grow as the write goes and a progress line is printed per batch
%   (documents, files copied, elapsed time, estimated time left). A
%   ndi.gui.component.ProgressBarWindow bar follows it when MATLAB has a
%   display (the window is silent when headless).
%
%   A failed batch is rolled back by sqlitedb.add, but the batches before it
%   stay written: the error says how many documents are already in DBFILE.
%
%   Options:
%     'BatchSize'  documents per batch (default 2000)
%     'Validate'   default true: validate each document against the schema
%                  as it is inserted. Documents built by did2.build were
%                  validated when they were built (did2.build.document,
%                  'Validate' true, the default), with the same
%                  did2.schema.cache.validateDocument, so a caller writing
%                  only such documents can pass false and skip the repeat.
%     'Label'      text for the progress lines and bar (default 'documents')
%     'Progress'   default true: print per-batch lines and show the bar
%
%   STATS fields: documents, batches, files (ingested files in DOCS),
%   convertSeconds (struct -> did2.document), addSeconds (copy + insert +
%   commit), seconds (total).
%
%   See also ndi.setup.V2.createDataset, ndi.setup.V2.createSession.

arguments
    dbFile (1,:) char
    docs cell
    options.BatchSize (1,1) double {mustBePositive, mustBeInteger} = 2000
    options.Validate (1,1) logical = true
    options.Label (1,:) char = 'documents'
    options.Progress (1,1) logical = true
end

n = numel(docs);
nFiles = cellfun(@ingestedCount, docs);
stats = struct('documents', n, 'batches', ceil(n / options.BatchSize), ...
    'files', sum(nFiles), 'convertSeconds', 0, 'addSeconds', 0, 'seconds', 0);
if n == 0
    return;
end

bar = [];
tag = '';
if options.Progress
    fprintf('writing %d %s (%d ingested file(s)) in %d batch(es) of up to %d\n', ...
        n, options.Label, stats.files, stats.batches, options.BatchSize);
    try
        bar = ndi.gui.component.ProgressBarWindow('NDI V2 write', 'GrabMostRecent', true);
        bar.setTimeout(hours(12));
        tag = ['write ' options.Label ' ' char(ndi.ido.unique_id())];
        bar.addBar('Label', sprintf('Writing %d %s', n, options.Label), 'Tag', tag, 'Auto', true);
    catch
        bar = [];
    end
end

db = did2.database.sqlitedb(dbFile);
closer = onCleanup(@() db.close());
t0 = tic;
done = 0;
filesDone = 0;
for b = 1:stats.batches
    idx = (b-1)*options.BatchSize + 1 : min(b*options.BatchSize, n);
    tc = tic;
    batch = cellfun(@(d) did2.document(d), docs(idx), 'UniformOutput', false);
    stats.convertSeconds = stats.convertSeconds + toc(tc);
    ta = tic;
    try
        db.add(batch, 'Validate', options.Validate);
    catch err
        error('ndi:setup:V2:writeFailed', ...
            ['Writing %s batch %d of %d (documents %d-%d) failed; %d document(s) of %d ' ...
             'are already in %s, so it is INCOMPLETE (write it again with ''Overwrite'', ' ...
             'true). Cause: %s'], options.Label, b, stats.batches, idx(1), idx(end), ...
            done, n, dbFile, err.message);
    end
    stats.addSeconds = stats.addSeconds + toc(ta);
    done = idx(end);
    filesDone = filesDone + sum(nFiles(idx));
    if options.Progress
        el = toc(t0);
        left = el / done * (n - done);
        fprintf('  %s: %d / %d documents (%.0f%%), %d / %d files, %s elapsed, ~%s left\n', ...
            options.Label, done, n, 100 * done / n, filesDone, stats.files, ...
            hms(el), hms(left));
        if ~isempty(bar)
            try bar.updateBar(tag, done / n); catch, end
        end
    end
end
stats.seconds = toc(t0);
if options.Progress
    fprintf('  %s written in %s (converting %s, copying + inserting %s)\n', options.Label, ...
        hms(stats.seconds), hms(stats.convertSeconds), hms(stats.addSeconds));
end
end

function k = ingestedCount(d)
k = 0;
if ~isfield(d, 'files') || ~isfield(d.files, 'file_info'), return; end
fi = d.files.file_info;
for a = 1:numel(fi)
    if ~isfield(fi(a), 'locations'), continue; end
    for c = 1:numel(fi(a).locations)
        if isfield(fi(a).locations(c), 'ingest') && fi(a).locations(c).ingest
            k = k + 1;
        end
    end
end
end

function s = hms(sec)
s = char(duration(0, 0, round(sec), 'Format', 'hh:mm:ss'));
end
