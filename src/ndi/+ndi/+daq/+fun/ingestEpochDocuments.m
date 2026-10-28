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
% |                           |   after each epoch completes (in parallel     |
% |                           |   mode via a parallel.pool.DataQueue).        |
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

% a counter that lives in a handle so the DataQueue callback can update it
counter = containers.Map('KeyType','char','ValueType','double');
counter('done') = 0;

numberOfWorkers = 0;
if numEpochs > 1
    numberOfWorkers = resolveWorkers(options.NumberOfWorkers);
end

if numberOfWorkers > 0
    usedParallel = true;
    q = parallel.pool.DataQueue;
    listener = afterEach(q, @(~) tick(counter, numEpochs, options.ProgressFcn));
    parfor (k=1:numEpochs, numberOfWorkers)
        docsPerEpoch{k} = ingestOneEpoch(daqreader, daqmetadatareaders, epochFiles{k}, epochIds{k});
        send(q, k);
    end
    % afterEach callbacks run asynchronously on the client; flush what is
    % pending, stop listening, and report the final tally if it was missed
    drawnow;
    delete(listener);
    if counter('done') < numEpochs
        counter('done') = numEpochs - 1;
        tick(counter, numEpochs, options.ProgressFcn);
    end
else
    for k=1:numEpochs
        docsPerEpoch{k} = ingestOneEpoch(daqreader, daqmetadatareaders, epochFiles{k}, epochIds{k});
        tick(counter, numEpochs, options.ProgressFcn);
    end
end

end % ingestEpochDocuments()

function d = ingestOneEpoch(daqreader, daqmetadatareaders, ef, epochId)
% INGESTONEEPOCH - create the documents for a single epoch (no database access)
    d = {};
    new_d = daqreader.ingest_epochfiles(ef, epochId);
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

function tick(counter, numTotal, progressFcn)
% TICK - count one finished epoch and report it
    counter('done') = counter('done') + 1;
    if ~isempty(progressFcn)
        try
            progressFcn(counter('done'), numTotal);
        catch ME
            % progress reporting must never break an ingest
            warning('NDI:daq:ingest:progressFailed', ...
                'Progress reporting failed: %s', ME.message);
        end
    end
end % tick()

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
