function result = largeFileListingScenario(options)
% LARGEFILELISTINGSCENARIO - Heavy cloud scenario: upload many small files and
%   walk the dataset file list with the keyset (cursor) API.
%
%   RESULT = ndi.test.helper.largeFileListingScenario('numFiles', 2000, ...)
%
%   Builds a local dataset containing a single demoNDISeries document whose
%   file series ('chunkdata.bin') has NUMFILES small member files, uploads it
%   to the NDI cloud, waits for server-side extraction, and then exercises the
%   cursor pagination client:
%       ndi.cloud.api.files.listFilesAll  (walk every page)
%       ndi.cloud.api.files.listFiles     (single page + cursor envelope)
%   asserting the walk is complete, de-duplicated, spans multiple pages, and
%   that the cursor advances to a non-overlapping next page.
%
%   This is a slow, cloud-dependent scenario — it creates and uploads NUMFILES
%   files — which is why it lives in ndi.test.helper and is NOT part of the
%   daily ndi.unittest suite. Run it on demand while validating the files
%   collection / cursor migration (issue ndi-cloud-node#142).
%
%   Requires NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD, and reads
%   CLOUD_API_ENVIRONMENT (set it to 'dev' to run against the dev API).
%
%   Name-Value options:
%       numFiles     (1,1) double  = 2000   number of file-series members to upload
%       pageLimit    (1,1) double  = 500    per-request page size for the cursor walk
%       keepDataset  (1,1) logical = false  if true, do NOT delete the cloud dataset
%       verbose      (1,1) logical = true
%
%   RESULT is a struct with fields: cloudDatasetId, numFiles, totalNumber,
%       numReturned, numRequests, uniqueUids, pagesNonOverlapping,
%       elapsedSeconds, passed. The function errors (does not return) if any
%       check fails, so it can be called directly or wrapped in a test.
%
%   Example:
%       setenv('CLOUD_API_ENVIRONMENT','dev');
%       r = ndi.test.helper.largeFileListingScenario('numFiles', 3000, 'pageLimit', 500);
%
%   See also: ndi.cloud.api.files.listFilesAll, ndi.cloud.api.files.listFiles

    arguments
        options.numFiles (1,1) double {mustBePositive} = 2000
        options.pageLimit (1,1) double {mustBePositive} = 500
        options.keepDataset (1,1) logical = false
        options.verbose (1,1) logical = true
        options.datasetNamePrefix (1,1) string = "NDI_UNITTEST_LARGE_FILELIST_"
    end

    assert(~isempty(getenv('NDI_CLOUD_USERNAME')) && ~isempty(getenv('NDI_CLOUD_PASSWORD')), ...
        'NDI:test:helper:MissingCredentials', ...
        ['Set NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD before running this scenario ', ...
        '(this is a local configuration issue, not an API problem).']);

    if options.verbose
        fprintf('largeFileListingScenario: %d files, pageLimit %d, CLOUD_API_ENVIRONMENT="%s"\n', ...
            options.numFiles, options.pageLimit, getenv('CLOUD_API_ENVIRONMENT'));
    end

    tStart = tic;

    % ----- 1. Build a local dataset with a file series of numFiles members -----
    workDir = tempname;
    mkdir(workDir);
    cleanupWork = onCleanup(@() localRemoveDir(workDir)); %#ok<NASGU>

    localDataset = ndi.dataset.dir('large_filelist_ds', workDir);

    memberDir = fullfile(workDir, 'level0');
    mkdir(memberDir);
    memberPaths = cell(1, options.numFiles);
    for i = 1:options.numFiles
        % Small, distinct content per member (content is irrelevant to the
        % listing test; the server keys files by uid, not by content).
        content = uint8(mod((1:16) * i, 251));
        p = fullfile(memberDir, sprintf('chunk_%06d.bin', i));
        fid = fopen(p, 'w');
        fwrite(fid, content, 'uint8');
        fclose(fid);
        memberPaths{i} = p;
    end

    doc = ndi.document('demoNDISeries', ...
        'base.name', 'large_filelist_series', ...
        'demoNDISeries.value', 1, ...
        'base.session_id', localDataset.id());
    doc = doc.addFileSeries('chunkdata.bin', memberPaths);
    localDataset.database_add(doc);

    if options.verbose
        fprintf('  built local file series with %d members\n', options.numFiles);
    end

    % ----- 2. Create + link + upload the cloud dataset -----
    uniqueName = options.datasetNamePrefix + string(did.ido.unique_id());
    [bCreate, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", uniqueName));
    assert(bCreate, 'NDI:test:helper:CreateDatasetFailed', ...
        'Failed to create cloud dataset "%s".', uniqueName);

    result = struct('cloudDatasetId', cloudId, 'numFiles', options.numFiles, ...
        'totalNumber', NaN, 'numReturned', NaN, 'numRequests', NaN, ...
        'uniqueUids', false, 'pagesNonOverlapping', false, ...
        'elapsedSeconds', NaN, 'passed', false);

    cleanupCloud = onCleanup(@() localMaybeDeleteDataset(cloudId, options.keepDataset, options.verbose)); %#ok<NASGU>

    remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, localDataset);
    localDataset.database_add(remoteDoc);

    if options.verbose, fprintf('  uploading dataset %s ...\n', cloudId); end
    successUpload = ndi.cloud.uploadDataset(localDataset);
    assert(successUpload, 'NDI:test:helper:UploadFailed', 'ndi.cloud.uploadDataset failed.');
    ndi.cloud.api.files.waitForAllBulkUploads(cloudId);

    % ----- 3. Walk the whole file list with the cursor client -----
    [bAll, filesAll, ~, urlAll] = ndi.cloud.api.files.listFilesAll(cloudId, 'limit', options.pageLimit);
    assert(bAll, 'NDI:test:helper:ListFilesAllFailed', 'listFilesAll failed.');

    uids = string({filesAll.uid});
    numReturned = numel(filesAll);
    numRequests = numel(urlAll);
    uniqueUids = (numel(unique(uids)) == numReturned);

    % ----- 4. Single page + cursor envelope + non-overlapping next page -----
    [b1, page1, resp1] = ndi.cloud.api.files.listFiles(cloudId, 'limit', options.pageLimit);
    assert(b1, 'NDI:test:helper:ListFilesFailed', 'listFiles (first page) failed.');
    env = resp1.Body.Data;
    totalNumber = double(env.totalNumber);

    pagesNonOverlapping = true;
    if isfield(env, 'hasMore') && ~isempty(env.hasMore) && logical(env.hasMore)
        [b2, page2] = ndi.cloud.api.files.listFiles(cloudId, ...
            'limit', options.pageLimit, 'after', string(env.cursor));
        assert(b2, 'NDI:test:helper:ListFilesFailed', 'listFiles (second page) failed.');
        pagesNonOverlapping = isempty(intersect(string({page1.uid}), string({page2.uid})));
    end

    % ----- 5. Assertions -----
    assert(numReturned == totalNumber, 'NDI:test:helper:CountMismatch', ...
        'listFilesAll returned %d files but the server reports totalNumber=%d.', ...
        numReturned, totalNumber);
    assert(numReturned >= options.numFiles, 'NDI:test:helper:TooFewFiles', ...
        'Expected at least %d files (series members) but listed %d.', ...
        options.numFiles, numReturned);
    assert(uniqueUids, 'NDI:test:helper:DuplicateUids', ...
        'The cursor walk returned duplicate uids (dedup/paging bug).');
    if options.numFiles > options.pageLimit
        assert(numRequests > 1, 'NDI:test:helper:NotMultiPage', ...
            'Expected a multi-page cursor walk (%d files, limit %d) but only %d request(s) were made.', ...
            options.numFiles, options.pageLimit, numRequests);
    end
    assert(pagesNonOverlapping, 'NDI:test:helper:PageOverlap', ...
        'The second cursor page overlapped the first (cursor did not advance).');

    % ----- result -----
    result.totalNumber = totalNumber;
    result.numReturned = numReturned;
    result.numRequests = numRequests;
    result.uniqueUids = uniqueUids;
    result.pagesNonOverlapping = pagesNonOverlapping;
    result.elapsedSeconds = toc(tStart);
    result.passed = true;

    if options.verbose
        fprintf(['  PASS: listed %d files across %d requests (limit %d); ', ...
            'totalNumber=%d, uniqueUids=%d, nonOverlap=%d, %.1fs\n'], ...
            numReturned, numRequests, options.pageLimit, totalNumber, ...
            uniqueUids, pagesNonOverlapping, result.elapsedSeconds);
    end
end

function localMaybeDeleteDataset(cloudId, keep, verbose)
    if keep
        if verbose
            fprintf('  keepDataset=true; leaving cloud dataset %s in place.\n', cloudId);
        end
        return;
    end
    try
        ndi.cloud.api.datasets.deleteDataset(cloudId, 'when', 'now');
        if verbose
            fprintf('  deleted cloud dataset %s.\n', cloudId);
        end
    catch ME
        warning('NDI:test:helper:CleanupFailed', ...
            'Failed to delete cloud dataset %s: %s', cloudId, ME.message);
    end
end

function localRemoveDir(p)
    try
        if isfolder(p)
            rmdir(p, 's');
        end
    catch
        % best-effort cleanup of the temp working directory
    end
end
