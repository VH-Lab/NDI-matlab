function [ok, report] = confirmFilesRecorded(cloudDatasetId, uids, paths, options)
%CONFIRMFILESRECORDED Make sure NDI Cloud recorded every file an upload sent.
%
%   [OK, REPORT] = ndi.cloud.upload.internal.confirmFilesRecorded(CLOUDDATASETID, UIDS, PATHS)
%
%   A batch (zip) upload returning success only means S3 has the zip. The
%   server then unpacks it and records each file in a separate step, and
%   that step can fail after the client has moved on: a dataset lost 327
%   files this way (ndi-cloud-node#175), and a zip of ~10,000 small files
%   outran the step's time limit with none recorded. Since that fix the
%   server keeps such files as not uploaded, so the loss is visible -- this
%   function is where the client looks.
%
%   1. Wait until every uid in UIDS is recorded as uploaded. Waiting goes
%      on while the count still to record keeps falling, and stops after
%      STALLTIMEOUT seconds in which none was recorded.
%   2. Upload the files still unrecorded again from PATHS (PATHS{k} is the
%      local copy of UIDS(k)): one at a time when there are at most
%      SINGLEFILELIMIT of them, otherwise as zip batches (capped by the
%      preferences Cloud.Upload.Max_File_Batch_Count and
%      Max_File_Batch_Size).
%   3. Wait for those the same way, with RESENDTIMEOUT as the stall limit;
%      any still unrecorded is a failure, listed in REPORT.pending.
%
%   Inputs:
%       cloudDatasetId - The cloud dataset id.
%       uids           - String array of the file uids the upload sent.
%       paths          - Cell array (or string array) of their local paths.
%
%   Name-Value Pairs:
%       'StallTimeout'    (double) - Seconds without a single newly recorded
%                                    file before resending. Default 900, the
%                                    server's batch step's own time limit.
%       'ResendTimeout'   (double) - The same, after resending. Default 300.
%       'SingleFileLimit' (double) - Resend one at a time up to this many
%                                    files; more go as zip batches.
%                                    Default 20.
%       'Verbose'         (logical) - Print progress. Default true.
%       'WaitFcn'         (function) - Seam for tests: [b, answer] =
%                                    WaitFcn(uids, timeout), as
%                                    ndi.cloud.api.files.waitForFileUpload.
%       'ResendFcn'       (function) - Seam for tests: [b, msg] =
%                                    ResendFcn(uid, path), as
%                                    ndi.cloud.uploadSingleFile with
%                                    'waitForUpload' false.
%       'ResendBatchFcn'  (function) - Seam for tests: [b, msg] =
%                                    ResendBatchFcn(uids, paths), as
%                                    ndi.cloud.upload.zipForUpload.
%
%   Outputs:
%       ok     - true iff every uid ended up recorded as uploaded.
%       report - struct: resent (uids uploaded again), pending (uids still
%                unrecorded at the end), resendErrors (cell of messages
%                from uploads that failed outright), message (empty when ok).
%
%   See also: ndi.cloud.sync.internal.uploadFilesForDatasetDocuments,
%             ndi.cloud.api.files.waitForFileUpload

    arguments
        cloudDatasetId (1,1) string
        uids (1,:) string
        paths
        options.StallTimeout (1,1) double {mustBePositive} = 900
        options.ResendTimeout (1,1) double {mustBePositive} = 300
        options.SingleFileLimit (1,1) double {mustBeNonnegative} = 20
        options.Verbose (1,1) logical = true
        options.WaitFcn = []
        options.ResendFcn = []
        options.ResendBatchFcn = []
    end

    paths = cellstr(paths);
    if numel(paths) ~= numel(uids)
        error('NDI:cloud:confirmFilesRecorded:sizeMismatch', ...
            'UIDS has %d entries but PATHS has %d.', numel(uids), numel(paths));
    end
    waitFcn = options.WaitFcn;
    if isempty(waitFcn)
        waitFcn = @(ids, t) ndi.cloud.api.files.waitForFileUpload(cloudDatasetId, ids, 'timeout', t);
    end
    resendFcn = options.ResendFcn;
    if isempty(resendFcn)
        resendFcn = @(id, p) ndi.cloud.uploadSingleFile(cloudDatasetId, id, p, 'waitForUpload', false);
    end
    resendBatchFcn = options.ResendBatchFcn;
    if isempty(resendBatchFcn)
        resendBatchFcn = @(ids, ps) resendAsZips(cloudDatasetId, ids, ps, options.Verbose);
    end

    report = struct('resent', strings(1, 0), 'pending', strings(1, 0), ...
        'resendErrors', {{}}, 'message', '');
    [uids, keep] = unique(uids, 'stable');
    paths = paths(keep);
    if isempty(uids)
        ok = true;
        return
    end

    % 1. Wait while the server keeps recording.
    pending = waitWhileRecording(waitFcn, uids, options.StallTimeout, numel(uids), options.Verbose);
    if isempty(pending)
        ok = true;
        return
    end

    % 2. Upload the unrecorded files again.
    pendingPaths = paths(arrayfun(@(u) find(uids == u, 1), pending));
    sent = strings(1, 0);
    if numel(pending) <= options.SingleFileLimit
        say(options.Verbose, ['NDI Cloud has not recorded %d of %d uploaded file(s) after ' ...
            '%.0f s without progress; uploading them again one at a time.'], ...
            numel(pending), numel(uids), options.StallTimeout);
        for k = 1:numel(pending)
            try
                [b, msg] = resendFcn(pending(k), pendingPaths{k});
            catch e   % e.g. the local copy is gone
                b = false;
                msg = e.message;
            end
            if b
                sent(end+1) = pending(k); %#ok<AGROW>
            else
                report.resendErrors{end+1} = sprintf('%s: %s', pending(k), char(string(msg)));
            end
        end
    else
        say(options.Verbose, ['NDI Cloud has not recorded %d of %d uploaded file(s) after ' ...
            '%.0f s without progress; uploading them again in zip batches.'], ...
            numel(pending), numel(uids), options.StallTimeout);
        try
            [b, msg] = resendBatchFcn(pending, pendingPaths);
        catch e
            b = false;
            msg = e.message;
        end
        if ~b
            % A failed batch may have sent some of them; wait for all.
            report.resendErrors{end+1} = sprintf('zip batch resend: %s', char(string(msg)));
        end
        sent = pending;
    end
    report.resent = sent;

    % 3. Wait for the resent files.
    stillPending = strings(1, 0);
    if ~isempty(sent)
        stillPending = waitWhileRecording(waitFcn, sent, options.ResendTimeout, ...
            numel(sent), options.Verbose);
    end
    report.pending = [setdiff(pending, sent, 'stable'), stillPending];
    ok = isempty(report.pending);
    if ok
        say(options.Verbose, 'All %d resent file(s) are now recorded by NDI Cloud.', numel(sent));
    else
        report.message = sprintf(['%d of %d uploaded file(s) were not recorded by NDI Cloud, ' ...
            'even after uploading them again (first: %s). Run the upload again with ' ...
            '''onlyMissing'' true to retry them.'], ...
            numel(report.pending), numel(uids), report.pending(1));
        if ~isempty(report.resendErrors)
            report.message = sprintf('%s First upload error: %s', report.message, report.resendErrors{1});
        end
        say(options.Verbose, '%s', report.message);
    end
end

function pending = waitWhileRecording(waitFcn, ids, stallTimeout, total, verbose)
    % Wait for IDS to be recorded for as long as the count still pending
    % keeps falling; return those still pending after STALLTIMEOUT seconds
    % with none newly recorded.
    pending = ids;
    while true
        [done, answer] = waitFcn(pending, stallTimeout);
        if done
            pending = strings(1, 0);
            return
        end
        stillPending = reshape(string(answer.pending), 1, []);
        if numel(stillPending) >= numel(pending)
            pending = stillPending;
            return   % nothing recorded for stallTimeout seconds
        end
        pending = stillPending;
        say(verbose, '%d of %d file(s) recorded by NDI Cloud so far; waiting.', ...
            total - numel(pending), total);
    end
end

function [b, msg] = resendAsZips(cloudDatasetId, uids, paths, verbose)
    % Upload the files again in zip batches, capped like any batch upload.
    % A zip entry is named by its file's name, which is its uid.
    bytes = cellfun(@(p) fileBytes(p), paths);
    manifest = struct('uid', cellstr(uids), 'file_path', reshape(paths, 1, []), ...
        'bytes', num2cell(bytes), 'is_uploaded', false);
    [b, msg] = ndi.cloud.upload.zipForUpload([], manifest, sum(bytes), char(cloudDatasetId), ...
        'Verbose', verbose, 'DebugLog', false);
end

function n = fileBytes(p)
    d = dir(p);
    if isempty(d)
        n = 0;   % gone: the zip step reports it
    else
        n = d(1).bytes;
    end
end

function say(verbose, varargin)
    if verbose
        fprintf(['[confirmFilesRecorded] ' varargin{1} '\n'], varargin{2:end});
    end
end
