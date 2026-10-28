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
% Whether the work is done on a parallel pool follows NDI's parallel
% preferences, through ndi.fun.parallelWorkers: by default a pool the user has
% already opened is used, otherwise the epochs run serially, and NDI never
% opens a pool unless Parallel.OpenPoolIfNone is true. Thread pools are not
% used (the raw-file readers and the compression are not thread-safe).
%
% On a pool, the unit of work is one data segment rather than one epoch: for
% readers that use ndi.daq.reader.mfdaq's ingest_epochfiles, each epoch is
% planned on the client (ingest_epochfiles_plan) and its segments
% (ingest_segment) are handed to workers as parfeval tasks, one at a time as
% workers free up. Every worker stays busy however unequal the epochs are,
% and one long epoch is spread over the whole pool. Other readers run one
% task per epoch. Results do not depend on the number of workers.
%
% This function takes name/value pairs that modify its behavior:
% |---------------------------|-----------------------------------------------|
% | Parameter (default)       | Description                                   |
% |---------------------------|-----------------------------------------------|
% | ProgressFcn ([])          | Function handle called as                     |
% |                           |   ProgressFcn(NUMDONE, NUMTOTAL) on the client|
% |                           |   as epochs progress (in parallel mode, as    |
% |                           |   each task finishes). NUMDONE counts         |
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

% per-epoch fractions done, in a handle shared with updateProgress
state = containers.Map('KeyType','char','ValueType','any');
state('frac') = zeros(1,numEpochs);

% readers using ndi.daq.reader.mfdaq's ingest_epochfiles take a ProgressFcn and
% can be planned segment by segment; any other reader works one epoch at a time
plansSegments = readerPlansSegments(daqreader);

numberOfWorkers = 0;
if numEpochs > 0
    numberOfWorkers = resolveWorkers(options.NumberOfWorkers);
end

if numberOfWorkers > 0
    usedParallel = true;
    docsPerEpoch = ingestOnPool(daqreader, daqmetadatareaders, epochFiles, epochIds, ...
        numberOfWorkers, plansSegments, state, options.ProgressFcn);
else
    for k=1:numEpochs
        epochProgress = [];
        if plansSegments && ~isempty(options.ProgressFcn)
            epochProgress = @(f) updateProgress(state, k, f, options.ProgressFcn);
        end
        docsPerEpoch{k} = ingestOneEpoch(daqreader, daqmetadatareaders, epochFiles{k}, epochIds{k}, epochProgress);
        updateProgress(state, k, 1, options.ProgressFcn);
    end
end

end % ingestEpochDocuments()

function docsPerEpoch = ingestOnPool(daqreader, daqmetadatareaders, epochFiles, epochIds, ...
    numberOfWorkers, plansSegments, state, progressFcn)
% INGESTONPOOL - compute the epochs' documents with parfeval tasks on the open pool
%
% The unit of work is one data segment (ndi.daq.reader.mfdaq/ingest_segment), so
% every worker stays busy however unequal the epochs are, and a single long epoch
% is spread over the whole pool. Each epoch is planned on the client first (this
% reads only file headers and writes the channel list); its metadata readers run
% as one more task. Up to NUMBEROFWORKERS tasks are in flight at a time, and a
% worker gets the next task as soon as it finishes one. Readers that are not
% planned segment by segment are run as one task per epoch. The segment files are
% attached in plan order, so the documents are the same as a serial ingest's.
    numEpochs = numel(epochFiles);
    pool = gcp('nocreate');

    epochDocs = cell(1,numEpochs);
    plans = cell(1,numEpochs);
    segmentFiles = cell(1,numEpochs);
    metaDocs = cell(1,numEpochs);
    docsPerEpoch = cell(numEpochs,1);

    taskEpoch = zeros(1,0);
    taskKind = cell(1,0);
    taskIndex = zeros(1,0);
    taskWeight = zeros(1,0);
    for k=1:numEpochs
        if plansSegments
            [epochDocs{k}, plans{k}] = daqreader.ingest_epochfiles_plan(epochFiles{k}, epochIds{k});
            n = numel(plans{k});
            segmentFiles{k} = cell(1,n);
            taskEpoch = [taskEpoch repmat(k,1,n)]; %#ok<AGROW>
            taskKind = [taskKind repmat({'segment'},1,n)]; %#ok<AGROW>
            taskIndex = [taskIndex 1:n]; %#ok<AGROW>
            taskWeight = [taskWeight [plans{k}.weight]]; %#ok<AGROW>
            if ~isempty(daqmetadatareaders)
                taskEpoch(end+1) = k; %#ok<AGROW>
                taskKind{end+1} = 'metadata'; %#ok<AGROW>
                taskIndex(end+1) = 0; %#ok<AGROW>
                taskWeight(end+1) = 0; %#ok<AGROW>
            end
        else
            taskEpoch(end+1) = k; %#ok<AGROW>
            taskKind{end+1} = 'epoch'; %#ok<AGROW>
            taskIndex(end+1) = 0; %#ok<AGROW>
            taskWeight(end+1) = 1; %#ok<AGROW>
        end
    end
    numTasks = numel(taskEpoch);
    remaining = accumarray(taskEpoch(:), 1, [numEpochs 1])';
    weightDone = zeros(1,numEpochs);

    futures = parallel.FevalFuture.empty;
    futureTask = zeros(1,0);
    nextTask = 1;
    try
        while nextTask <= numTasks || ~isempty(futures)
            while nextTask <= numTasks && numel(futures) < numberOfWorkers
                k = taskEpoch(nextTask);
                planEntry = [];
                readers = {};
                switch taskKind{nextTask}
                    case 'segment'
                        planEntry = plans{k}(taskIndex(nextTask));
                    otherwise
                        readers = daqmetadatareaders;
                end
                futures(end+1) = parfeval(pool, @runTask, 1, daqreader, readers, ...
                    epochFiles{k}, epochIds{k}, taskKind{nextTask}, planEntry); %#ok<AGROW>
                futureTask(end+1) = nextTask; %#ok<AGROW>
                nextTask = nextTask + 1;
            end
            [idx, out] = fetchNext(futures);
            t = futureTask(idx);
            futures(idx) = [];
            futureTask(idx) = [];

            k = taskEpoch(t);
            switch taskKind{t}
                case 'segment'
                    segmentFiles{k}{taskIndex(t)} = out;
                case 'metadata'
                    metaDocs{k} = out;
                case 'epoch'
                    docsPerEpoch{k} = out;
            end
            remaining(k) = remaining(k) - 1;
            weightDone(k) = weightDone(k) + taskWeight(t);
            if remaining(k) == 0
                updateProgress(state, k, 1, progressFcn);
            else
                updateProgress(state, k, min(weightDone(k), 0.999), progressFcn);
            end
        end
    catch ME
        cancel(futures);
        rethrow(ME);
    end
    for k=1:numEpochs
        updateProgress(state, k, 1, progressFcn); % e.g., an epoch with nothing to write
    end

    if plansSegments
        for k=1:numEpochs
            d = ndi.daq.reader.mfdaq.ingest_attach_segments(epochDocs{k}, plans{k}, segmentFiles{k});
            docsPerEpoch{k} = cat(1, {d}, metaDocs{k}(:));
        end
    end
end % ingestOnPool()

function out = runTask(daqreader, daqmetadatareaders, ef, epochId, kind, planEntry)
% RUNTASK - one unit of ingestion work, run on a pool worker
    switch kind
        case 'segment'
            out = daqreader.ingest_segment(ef, planEntry);
        case 'metadata'
            out = metadataDocs(daqmetadatareaders, ef, epochId);
        case 'epoch'
            out = ingestOneEpoch(daqreader, daqmetadatareaders, ef, epochId, []);
    end
end % runTask()

function d = metadataDocs(daqmetadatareaders, ef, epochId)
% METADATADOCS - the metadata readers' documents for one epoch
    d = {};
    for j=1:numel(daqmetadatareaders)
        new_d = daqmetadatareaders{j}.ingest_epochfiles(ef, epochId);
        if ~iscell(new_d)
            new_d = {new_d};
        end
        d = cat(1,d,new_d(:));
    end
end % metadataDocs()

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
    d = cat(1,d,new_d(:),metadataDocs(daqmetadatareaders, ef, epochId));
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
    state('frac') = frac; %#ok<NASGU> state is a containers.Map, a handle: this updates the caller's map
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

function tf = readerPlansSegments(daqreader)
% READERPLANSSEGMENTS - does DAQREADER use ndi.daq.reader.mfdaq's ingest_epochfiles?
%
% True when the method is ndi.daq.reader.mfdaq's own: then it takes a ProgressFcn
% and can be split into INGEST_EPOCHFILES_PLAN and INGEST_SEGMENT. A subclass that
% overrides ingest_epochfiles keeps its own signature and is run whole.
    tf = false;
    if isempty(daqreader)
        return;
    end
    mc = metaclass(daqreader);
    m = mc.MethodList(strcmp({mc.MethodList.Name}, 'ingest_epochfiles'));
    tf = ~isempty(m) && strcmp(m(1).DefiningClass.Name, 'ndi.daq.reader.mfdaq');
end % readerPlansSegments()

function numberOfWorkers = resolveWorkers(numberOfWorkersOverride)
% RESOLVEWORKERS - number of tasks to keep in flight, following NDI's parallel preferences
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
