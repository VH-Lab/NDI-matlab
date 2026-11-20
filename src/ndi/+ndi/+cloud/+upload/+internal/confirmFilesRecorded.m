function [ok, report] = confirmFilesRecorded(cloudDatasetId, uids, paths, options)
%CONFIRMFILESRECORDED Make sure NDI Cloud recorded every file an upload sent.
%
%   [OK, REPORT] = ndi.cloud.upload.internal.confirmFilesRecorded(CLOUDDATASETID, UIDS, PATHS)
%
%   A batch (zip) upload returning success only means S3 has the zip. The
%   server then unpacks it and records each file in a separate step, and
%   that step can fail after the client has moved on: a dataset lost 327
%   files this way (ndi-cloud-node#175). Since that fix the server keeps
%   such files as not uploaded, so the loss is visible -- this function is
%   where the client looks.
%
%   1. Wait until every uid in UIDS is recorded as uploaded. Waiting goes
%      on while the count still to record keeps falling, and stops after
%      STALLTIMEOUT seconds in which none was recorded.
%   2. Upload each file still unrecorded again, one at a time from PATHS
%      (PATHS{k} is the local copy of UIDS(k)).
%   3. Wait for those (RESENDTIMEOUT seconds); any still unrecorded is a
%      failure, listed in REPORT.pending.
%
%   Inputs:
%       cloudDatasetId - The cloud dataset id.
%       uids           - String array of the file uids the upload sent.
%       paths          - Cell array (or string array) of their local paths.
%
%   Name-Value Pairs:
%       'StallTimeout'  (double) - Seconds without a single newly recorded
%                                  file before resending. Default 900, the
%                                  server's batch step's own time limit.
%       'ResendTimeout' (double) - Seconds to wait for the resent files to
%                                  be recorded. Default 300.
%       'Verbose'       (logical) - Print progress. Default true.
%       'WaitFcn'       (function) - Seam for tests: [b, answer] =
%                                  WaitFcn(uids, timeout), as
%                                  ndi.cloud.api.files.waitForFileUpload.
%       'ResendFcn'     (function) - Seam for tests: [b, msg] =
%                                  ResendFcn(uid, path), as
%                                  ndi.cloud.uploadSingleFile with
%                                  'waitForUpload' false.
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
        options.Verbose (1,1) logical = true
        options.WaitFcn = []
        options.ResendFcn = []
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

    report = struct('resent', strings(1, 0), 'pending', strings(1, 0), ...
        'resendErrors', {{}}, 'message', '');
    [uids, keep] = unique(uids, 'stable');
    paths = paths(keep);
    if isempty(uids)
        ok = true;
        return
    end

    % 1. Wait while the server keeps recording.
    pending = uids;
    while true
        [done, answer] = waitFcn(pending, options.StallTimeout);
        if done
            ok = true;
            return
        end
        stillPending = reshape(string(answer.pending), 1, []);
        if numel(stillPending) >= numel(pending)
            pending = stillPending;
            break   % nothing recorded for StallTimeout seconds
        end
        pending = stillPending;
        say(options.Verbose, '%d of %d uploaded file(s) recorded by NDI Cloud so far; waiting.', ...
            numel(uids) - numel(pending), numel(uids));
    end

    % 2. Upload the unrecorded files again, one at a time.
    say(options.Verbose, ['NDI Cloud has not recorded %d of %d uploaded file(s) after %.0f s ' ...
        'without progress; uploading them again one at a time.'], ...
        numel(pending), numel(uids), options.StallTimeout);
    sent = strings(1, 0);
    for k = 1:numel(pending)
        j = find(uids == pending(k), 1);
        try
            [b, msg] = resendFcn(pending(k), paths{j});
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
    report.resent = sent;

    % 3. Wait for the resent files.
    if ~isempty(sent)
        [done, answer] = waitFcn(sent, options.ResendTimeout);
        if done
            stillPending = strings(1, 0);
        else
            stillPending = reshape(string(answer.pending), 1, []);
        end
    else
        stillPending = strings(1, 0);
    end
    report.pending = [setdiff(pending, sent, 'stable'), stillPending];
    ok = isempty(report.pending);
    if ok
        say(options.Verbose, 'All %d resent file(s) are now recorded by NDI Cloud.', numel(sent));
    else
        report.message = sprintf(['%d of %d uploaded file(s) were never recorded by NDI Cloud, ' ...
            'even after uploading them again (first: %s). Run the upload again with ' ...
            '''onlyMissing'' true to retry them.'], ...
            numel(report.pending), numel(uids), report.pending(1));
        if ~isempty(report.resendErrors)
            report.message = sprintf('%s First upload error: %s', report.message, report.resendErrors{1});
        end
        say(options.Verbose, '%s', report.message);
    end
end

function say(verbose, varargin)
    if verbose
        fprintf(['[confirmFilesRecorded] ' varargin{1} '\n'], varargin{2:end});
    end
end
