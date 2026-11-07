function [ok, urls, msg] = signedUploadURLs(cloudDatasetId, uids, crcs, folder, options)
% NDI.CLOUD.UPLOAD.SIGNEDUPLOADURLS - many signed upload URLs at once, with one curl
%
%   [OK, URLS, MSG] = ndi.cloud.upload.signedUploadURLs(CLOUDDATASETID, UIDS, CRCS, FOLDER)
%   [...] = ndi.cloud.upload.signedUploadURLs(..., 'Parallel', N)
%
%   Asks NDI Cloud for a pre-signed upload URL for each file uid in UIDS,
%   each signed for the CRC-32 in CRCS (ndi.fun.file.crc32; '' for
%   none), as ndi.cloud.api.files.getFileUploadURL does one at a time --
%   but N requests at a time (default 8) from one curl, and with the
%   dataset's organization looked up once (getFileUploadURL looks it up
%   on every call). For a batch of 16 chunks this is a fraction of a
%   second instead of several.
%
%   The requests carry your login token, so the curl config is handed to
%   curl on its standard input: it is never written to disk or shown on
%   a command line. Each answer is written to FOLDER and deleted once
%   read. OK is false (and URLS empty) if any URL could not be had; the
%   caller then asks one at a time. Needs ndi.cloud.upload.CurlSender's
%   curl (7.68+).
%
%   See also: ndi.cloud.upload.SessionWriter, ndi.cloud.upload.CurlSender,
%             ndi.cloud.api.files.getFileUploadURL

    arguments
        cloudDatasetId (1,:) char
        uids cell
        crcs cell
        folder (1,:) char
        options.Parallel (1,1) double {mustBeInteger, mustBePositive} = 8
        options.Timeout (1,1) double {mustBePositive} = 120
    end
    ok = false;
    urls = {};
    msg = '';
    n = numel(uids);
    if n == 0
        ok = true;
        return
    end
    if ~ndi.cloud.upload.CurlSender.supported()
        msg = 'no curl new enough for parallel requests';
        return
    end
    org = organizationOf(cloudDatasetId);
    if isempty(org)
        msg = 'could not look up the dataset''s organization';
        return
    end
    if ~isfolder(folder), mkdir(folder); end
    token = char(ndi.cloud.authenticate());

    stem = fullfile(folder, ['urls-' char(did.ido.unique_id())]);
    outs = arrayfun(@(i) sprintf('%s-%d.json', stem, i), 1:n, 'UniformOutput', false);
    log = [stem '.log'];
    cleaner = onCleanup(@() deleteFiles([outs {log}]));
    apiUrls = cell(1, n);
    for i = 1:n
        u = ndi.cloud.api.url('get_file_upload_url', 'dataset_id', cloudDatasetId, ...
            'organization_id', org, 'file_uid', char(uids{i}));
        if ~isempty(crcs{i})
            q = matlab.net.QueryParameter('checksumCRC32', char(crcs{i}));
            if isempty(u.Query), u.Query = q; else, u.Query = [u.Query q]; end
        end
        apiUrls{i} = char(u);
    end
    cfg = ndi.cloud.upload.signedUploadURLs_config(apiUrls, token, outs);

    p = ndi.util.startProcess({'curl', '--parallel', '--parallel-immediate', ...
        '--parallel-max', sprintf('%d', options.Parallel), '--config', '-'}, log, log);
    in = p.getOutputStream();
    in.write(typecast(unicode2native(cfg, 'UTF-8'), 'int8'));
    in.close();
    if ~p.waitFor(options.Timeout, java.util.concurrent.TimeUnit.SECONDS)
        p.destroy();
        msg = sprintf('curl did not finish within %g s', options.Timeout);
        return
    end

    urls = cell(1, n);
    for i = 1:n
        try
            answer = jsondecode(fileread(outs{i}));
            urls{i} = char(answer.url);
        catch
            urls = {};
            msg = sprintf('no upload URL came back for %s', char(uids{i}));
            if isfile(log)
                detail = strtrim(fileread(log));
                if ~isempty(detail)
                    msg = sprintf('%s (%s)', msg, detail(1:min(end, 300)));
                end
            end
            return
        end
    end
    ok = true;
end

function org = organizationOf(cloudDatasetId)
% The dataset's organization id, asked once per dataset per MATLAB.
    persistent known
    if isempty(known)
        known = containers.Map('KeyType', 'char', 'ValueType', 'char');
    end
    org = '';
    if isKey(known, cloudDatasetId)
        org = known(cloudDatasetId);
        return
    end
    [b, info] = ndi.cloud.api.datasets.getDataset(cloudDatasetId);
    if b && isfield(info, 'organizationId') && ~isempty(info.organizationId)
        org = char(info.organizationId);
        known(cloudDatasetId) = org;
    end
end

function deleteFiles(files)
    for i = 1:numel(files)
        if isfile(files{i}), delete(files{i}); end
    end
end
