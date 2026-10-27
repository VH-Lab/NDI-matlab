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
% This function takes name/value pairs that modify its behavior:
% |---------------------------|-----------------------------------------------|
% | Parameter (default)       | Description                                   |
% |---------------------------|-----------------------------------------------|
% | UseParallel (false)       | Compute the epochs on a parallel pool. Falls  |
% |                           |   back to serial (with a warning) when the    |
% |                           |   Parallel Computing Toolbox is unavailable,  |
% |                           |   the pool cannot be started, or the pool is  |
% |                           |   a thread pool.                              |
% | NumWorkers ([])           | Pool size to use when UseParallel is true.    |
% |                           |   Empty uses gcp() (the open pool, or a new   |
% |                           |   default pool). N > 0 ensures a pool of N    |
% |                           |   workers.                                    |
% | ProgressFcn ([])          | Function handle called as                     |
% |                           |   ProgressFcn(NUMDONE, NUMTOTAL) on the client|
% |                           |   after each epoch completes (in parallel     |
% |                           |   mode via a parallel.pool.DataQueue).        |
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
    options.UseParallel (1,1) logical = false
    options.NumWorkers double {mustBeScalarOrEmpty, mustBeNonnegative, mustBeInteger} = []
    options.ProgressFcn = []
end

numEpochs = numel(epochFiles);
assert(numel(epochIds)==numEpochs, ...
    'NDI:daq:ingest:sizeMismatch', 'EPOCHFILES and EPOCHIDS must have the same number of entries.');

docsPerEpoch = cell(numEpochs,1);
usedParallel = false;

% a counter that lives in a handle so the DataQueue callback can update it
counter = containers.Map('KeyType','char','ValueType','double');
counter('done') = 0;

pool = [];
if options.UseParallel && numEpochs > 1
    pool = resolvePool(options.NumWorkers);
end

if ~isempty(pool)
    usedParallel = true;
    q = parallel.pool.DataQueue;
    listener = afterEach(q, @(~) tick(counter, numEpochs, options.ProgressFcn));
    parfor k=1:numEpochs
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

function pool = resolvePool(numWorkers)
% RESOLVEPOOL - return a usable process-based parallel pool, or [] for serial
    pool = [];
    if isempty(ver('parallel')) || ~license('test','Distrib_Computing_Toolbox')
        warning('NDI:daq:ingest:parallelUnavailable', ...
            ['UseParallel was requested but the Parallel Computing Toolbox ' ...
             'is not available. Ingesting serially.']);
        return;
    end
    try
        p = gcp('nocreate');
        if isempty(numWorkers)
            if isempty(p)
                p = gcp();
            end
        elseif isempty(p) || p.NumWorkers ~= numWorkers
            if ~isempty(p)
                delete(p);
            end
            p = parpool(numWorkers);
        end
    catch ME
        warning('NDI:daq:ingest:parallelUnavailable', ...
            'Could not start a parallel pool (%s). Ingesting serially.', ME.message);
        return;
    end
    if isempty(p)
        warning('NDI:daq:ingest:parallelUnavailable', ...
            'No parallel pool is available. Ingesting serially.');
        return;
    end
    if isa(p, 'parallel.ThreadPool')
        % ingestion reads raw files with third-party readers and writes
        % compressed archives; that is not supported on thread workers
        warning('NDI:daq:ingest:threadPool', ...
            ['The current parallel pool is a thread pool, which ingestion does ' ...
             'not support. Open a process pool (parpool(''Processes'')). Ingesting serially.']);
        return;
    end
    pool = p;
end % resolvePool()
