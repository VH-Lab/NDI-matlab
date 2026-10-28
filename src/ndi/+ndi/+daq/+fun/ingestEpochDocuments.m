function [docsPerEpoch, usedParallel] = ingestEpochDocuments(daqreader, daqmetadatareaders, epochFiles, epochIds, options)
% INGESTEPOCHDOCUMENTS - build the ingested-data documents for a set of epochs
%
% [DOCSPEREPOCH, USEDPARALLEL] = ndi.daq.fun.ingestEpochDocuments(DAQREADER, ...
%     DAQMETADATAREADERS, EPOCHFILES, EPOCHIDS, ...)
%
% Runs DAQREADER.ingest_epochfiles and each DAQMETADATAREADERS{j}.ingest_epochfiles
% for every epoch described by EPOCHFILES{k} (a cell array of file names) and
% EPOCHIDS{k} (the epoch id). This is the expensive part of ingestion: the raw
% data are read and compressed into temporary .nbf.tgz files that are attached
% to the returned documents.
%
% DOCSPEREPOCH{k} is a column cell array of the ndi.document objects created for
% epoch k, in the same order as a serial ndi.daq.system/ingest produces them
% (the daqreader document followed by one document per metadata reader).
%
% No database is touched here: the documents are NOT added to any database,
% so the caller remains responsible for serializing all database writes. That
% is what makes it safe to compute the epochs on parallel workers.
%
% Whether the epochs are computed on a parallel pool follows NDI's parallel
% preferences, through ndi.fun.parallelWorkers: by default a pool the user has
% already opened is used, otherwise the epochs run serially, and NDI never
% opens a pool unless Parallel.OpenPoolIfNone is true. Thread pools are not
% used (the raw-file readers and the compression are not thread-safe).
% Results do not depend on the number of workers.
%
% This function takes name/value pairs that modify its behavior:
% |---------------------------|-----------------------------------------------|
% | Parameter (default)       | Description                                   |
% |---------------------------|-----------------------------------------------|
% | ProgressFcn ([])          | Function handle called as                     |
% |                           |   ProgressFcn(NUMDONE, NUMTOTAL) on the client|
% |                           |   as epochs progress (in parallel mode via a  |
% |                           |   parallel.pool.DataQueue). NUMDONE counts    |
% |                           |   epochs and is fractional while an epoch is  |
% |                           |   underway: readers whose ingest_epochfiles   |
% |                           |   is ndi.daq.reader.mfdaq's report each       |
% |                           |   segment they write. It is called only when  |
% |                           |   NUMDONE changes, so each whole number is    |
% |                           |   reported once.                              |
% | NumberOfWorkers ([])      | Overrides the preferences for this call;      |
% |                           |   passed to ndi.fun.parallelWorkers. 0 forces |
% |                           |   serial.                                     |
% |---------------------------|-----------------------------------------------|
%
% USEDPARALLEL is true if the epochs were actually computed on a pool.
%
% See also: ndi.daq.system/ingest, ndi.session/ingest
%

arguments
    daqreader
    daqmetadatareaders cell
    epochFiles cell
    epochIds cell
    options.ProgressFcn = []
    options.NumberOfWorkers double {mustBeScalarOrEmpty, mustBeNonnegative} = []
end

numEpochs = numel(epochFiles);
assert(numel(epochIds)==numEpochs, ...
    'NDI:daq:ingest:sizeMismatch', 'EPOCHFILES and EPOCHIDS must have the same number of entries.');

docsPerEpoch = cell(numEpochs,1);
usedParallel = false;

% per-epoch fractions done, in a handle so the DataQueue callback can update them
state = containers.Map('KeyType','char','ValueType','any');
state('frac') = zeros(1,numEpochs);

% only readers using ndi.daq.reader.mfdaq's ingest_epochfiles take a ProgressFcn;
% any other reader reports per epoch only
withinEpoch = ~isempty(options.ProgressFcn) && readerReportsProgress(daqreader);

numberOfWorkers = 0;
if numEpochs > 1
    numberOfWorkers = resolveWorkers(options.NumberOfWorkers);
end

if numberOfWorkers > 0
    usedParallel = true;
    q = parallel.pool.DataQueue;
    listener = afterEach(q, @(msg) updateProgress(state, msg(1), msg(2), options.ProgressFcn));
    parfor (k=1:numEpochs, numberOfWorkers)
        epochProgress = [];
        if withinEpoch
            epochProgress = @(f) send(q, [k f]);
        end
        docsPerEpoch{k} = ingestOneEpoch(daqreader, daqmetadatareaders, epochFiles{k}, epochIds{k}, epochProgress);
        send(q, [k 1]);
    end
    % afterEach callbacks run asynchronously on the client; flush what is
    % pending, stop listening, and report the final tally if it was missed
    drawnow;
    delete(listener);
    for k=1:numEpochs
        updateProgress(state, k, 1, options.ProgressFcn);
    end
else
    for k=1:numEpochs
        epochProgress = [];
        if withinEpoch
            epochProgress = @(f) updateProgress(state, k, f, options.ProgressFcn);
        end
        docsPerEpoch{k} = ingestOneEpoch(daqreader, daqmetadatareaders, epochFiles{k}, epochIds{k}, epochProgress);
        updateProgress(state, k, 1, options.ProgressFcn);
    end
end

end % ingestEpochDocuments()

function d = ingestOneEpoch(daqreader, daqmetadatareaders, ef, epochId, epochProgress)
% INGESTONEEPOCH - create the documents for a single epoch (no database access)
    d = {};
    if isempty(epochProgress)
        new_d = daqreader.ingest_epochfiles(ef, epochId);
    else
        new_d = daqreader.ingest_epochfiles(ef, epochId, 'ProgressFcn', epochProgress);
    end
    if ~iscell(new_d)
        new_d = {new_d};
    end
    d = cat(1,d,new_d(:));
    for j=1:numel(daqmetadatareaders)
        new_d = daqmetadatareaders{j}.ingest_epochfiles(ef, epochId);
        if ~iscell(new_d)
            new_d = {new_d};
        end
        d = cat(1,d,new_d(:));
    end
end % ingestOneEpoch()

function updateProgress(state, k, fraction, progressFcn)
% UPDATEPROGRESS - record that epoch K is FRACTION done and report the total
%
% Fractions only move forward, and PROGRESSFCN is called only when the total
% changes, so a reader's own final report and the epoch's completion do not
% count the epoch twice.
    frac = state('frac');
    newFraction = max(frac(k), min(max(fraction,0),1));
    if newFraction == frac(k)
        return;
    end
    frac(k) = newFraction;
    state('frac') = frac;
    if ~isempty(progressFcn)
        try
            progressFcn(sum(frac), numel(frac));
        catch ME
            % progress reporting must never break an ingest
            warning('NDI:daq:ingest:progressFailed', ...
                'Progress reporting failed: %s', ME.message);
        end
    end
end % updateProgress()

function tf = readerReportsProgress(daqreader)
% READERREPORTSPROGRESS - does DAQREADER's ingest_epochfiles take a ProgressFcn?
%
% True when the method is ndi.daq.reader.mfdaq's own; a subclass that overrides
% ingest_epochfiles keeps its own signature and is called without one.
    tf = false;
    if isempty(daqreader)
        return;
    end
    mc = metaclass(daqreader);
    m = mc.MethodList(strcmp({mc.MethodList.Name}, 'ingest_epochfiles'));
    tf = ~isempty(m) && strcmp(m(1).DefiningClass.Name, 'ndi.daq.reader.mfdaq');
end % readerReportsProgress()

function numberOfWorkers = resolveWorkers(numberOfWorkersOverride)
% RESOLVEWORKERS - worker limit for the parfor, following NDI's parallel preferences
    if isempty(numberOfWorkersOverride)
        numberOfWorkers = ndi.fun.parallelWorkers();
    elseif numberOfWorkersOverride < 1
        numberOfWorkers = 0; % forced serial
        return;
    else
        numberOfWorkers = ndi.fun.parallelWorkers('numberOfWorkers', numberOfWorkersOverride);
    end
    if numberOfWorkers > 0
        pool = gcp('nocreate');
        if isa(pool, 'parallel.ThreadPool')
            % ingestion reads raw files with third-party readers and writes
            % compressed archives; that is not supported on thread workers
            warning('NDI:daq:ingest:threadPool', ...
                ['The open parallel pool is a thread pool, which ingestion does ' ...
                 'not support. Open a process pool (parpool(''Processes'')) to ' ...
                 'ingest in parallel. Ingesting serially.']);
            numberOfWorkers = 0;
        end
    end
end % resolveWorkers()
