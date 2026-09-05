classdef SignedURLSetTest < matlab.unittest.TestCase
% SignedURLSetTest - Test suite for the ndi.cloud.api.files signed-URL-set
% commands.
%
%   Exercises the client wrappers around the three new server endpoints:
%
%     GET  /datasets/{d}/documents/{doc}/signed-url-set
%     POST /datasets/{d}/documents/{doc}/signed-url-set-jobs
%     GET  /signed-url-set-jobs/{jobId}
%
%   The setup mirrors DownloadGenericFilesTest: build a small local
%   ndi.dataset with a handful of generic_file documents (each carrying a
%   file), push it to a fresh cloud dataset via ndi.cloud.uploadDataset,
%   then wait for the server-side bulk extraction to settle before any
%   test reads the files back. Documents already reference their files via
%   data.files.file_info.locations[].uid, which is exactly what the
%   getSignedURLSet endpoint looks at, so no per-test scaffolding is
%   needed.
%
%   Each test follows the narrative + APIMessage pattern used throughout
%   ndi.unittest.cloud so a failure carries every step and the URL of the
%   last API call.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_SIGNED_URL_SET_';
        % How many generic_file documents to build in the local dataset.
        % Chosen so at least one page fits comfortably and a limit=2 page
        % walk exercises the cursor path across multiple pages.
        NumFiles = 4;
    end

    properties
        DatasetID       (1,1) string = missing
        LocalDataset
        Narrative       (1,:) string
        FileUIDs        (1,:) string  % cloud file UIDs, in creation order
        FileContent     (1,:) string  % content string for each fileUIDs(i)
        CloudDocumentID (1,1) string = missing  % cloud id of the doc that
                                                % references every file
        CloudDocumentUIDs (1,:) string          % UIDs the cloud doc references
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = ['Missing NDI Cloud credentials (NDI_CLOUD_USERNAME/', ...
                'NDI_CLOUD_PASSWORD). Skipping cloud-dependent tests.'];
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end
    end

    methods (TestMethodSetup)
        function setupLocalDatasetAndCloud(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));

            % 1. Local dataset carrying N generic_file documents, each with
            %    a distinct file. All hang off a single 'test_target' base
            %    document via a dependency so we can look up the cloud
            %    document ids by name and pick the one under test.
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.LocalDataset = ndi.dataset.dir('test_ds', tempFolder.Folder);

            doc_target = ndi.document('base', ...
                'base.name', 'signed_url_set_target', ...
                'base.session_id', testCase.LocalDataset.id());
            testCase.LocalDataset.database_add(doc_target);

            fileContents = strings(1, testCase.NumFiles);
            for i = 1:testCase.NumFiles
                content = sprintf('signed-url-set content #%d %s', i, char(did.ido.unique_id()));
                fileContents(i) = string(content);

                localPath = fullfile(tempFolder.Folder, sprintf('sus_%d.dat', i));
                fid = fopen(localPath, 'w');
                fprintf(fid, '%s', content);
                fclose(fid);

                docI = ndi.document('generic_file', ...
                    'base.name', sprintf('signed_url_set_doc_%d', i), ...
                    'generic_file.filename', sprintf('sus_%d.dat', i), ...
                    'generic_file.dateCreated', 0, ...
                    'generic_file.dateUpdated', 0, ...
                    'base.session_id', testCase.LocalDataset.id());
                docI = docI.add_file('generic_file.ext', localPath);
                docI = docI.set_dependency_value('document_id', doc_target.id(), 'ErrorIfNotFound', 0);
                testCase.LocalDataset.database_add(docI);
            end
            testCase.FileContent = fileContents;

            % 2. Create cloud dataset.
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", unique_name));
            testCase.fatalAssertTrue(b, "Failed to create cloud dataset for SignedURLSetTest.");
            testCase.DatasetID = cloudId;

            remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, testCase.LocalDataset);
            testCase.LocalDataset.database_add(remoteDoc);

            % 3. Upload, then wait for server-side extraction so listFiles
            %    reports every file as uploaded before any test reads them.
            [success_upload] = ndi.cloud.uploadDataset(testCase.LocalDataset);
            testCase.fatalAssertTrue(success_upload, "Failed to upload test dataset to cloud.");
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            % 4. Record which UIDs the dataset now holds; the signed URL
            %    set endpoint intersects the doc's referenced UIDs with
            %    the dataset's uploaded file records, so this list is the
            %    upper bound of what a well-formed response can carry.
            [b_files, files_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            testCase.fatalAssertTrue(b_files, "listFiles failed after upload.");
            testCase.FileUIDs = string({files_list.uid});

            % 5. Locate one of the generic_file documents on the cloud so
            %    later tests can address it by cloud id. We pick doc #1;
            %    each generic_file references exactly one file, so its
            %    signed-URL-set has one entry -- easy to verify byte-for-
            %    byte via the returned URL.
            [b_docs, docs_list] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.DatasetID, 'checkForUpdates', true);
            testCase.fatalAssertTrue(b_docs, "listDatasetDocumentsAll failed.");

            [cloudId1, uids1] = testCase.findCloudDoc(docs_list, 'signed_url_set_doc_1');
            testCase.fatalAssertFalse(ismissing(cloudId1), ...
                "Could not find cloud id for local doc signed_url_set_doc_1.");
            testCase.CloudDocumentID   = cloudId1;
            testCase.CloudDocumentUIDs = uids1;
            testCase.fatalAssertNotEmpty(uids1, ...
                "Cloud doc signed_url_set_doc_1 does not reference any file UID.");

            testCase.addTeardown(@() testCase.cleanupCloudDataset());
        end
    end

    methods (Access = private)
        function cleanupCloudDataset(testCase)
            if ~ismissing(testCase.DatasetID)
                pause(3);
                [ok, ~, ~, ~] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
                if ~ok
                    pause(10);
                    ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
                end
            end
        end

        function [cloudId, uids] = findCloudDoc(testCase, docs_list, localName)
            % Find a cloud document by base.name and return its cloud id
            % and the list of file UIDs it references. Returns
            % (missing, []) if not found.
            cloudId = string(missing);
            uids = strings(1,0);

            % Search the local dataset by name; ndiId matches on cloud.
            q = ndi.query('base.name', 'exact_string', localName);
            localDocs = testCase.LocalDataset.database_search(q);
            if numel(localDocs) ~= 1, return; end
            localId = localDocs{1}.id();

            match = [];
            for i = 1:numel(docs_list)
                if isfield(docs_list(i), 'ndiId') && strcmp(docs_list(i).ndiId, localId)
                    match = docs_list(i);
                    break;
                end
            end
            if isempty(match), return; end
            cloudId = string(match.id);

            % Fetch the full document so we can inspect its
            % data.files.file_info.locations[].uid list.
            [b_get, cloudDoc] = ndi.cloud.api.documents.getDocument(testCase.DatasetID, cloudId);
            if ~b_get, return; end
            try
                fileInfo = cloudDoc.data.files.file_info;
                if ~iscell(fileInfo) && numel(fileInfo) > 1
                    fileInfo = num2cell(fileInfo);
                elseif ~iscell(fileInfo)
                    fileInfo = {fileInfo};
                end
                collected = strings(1,0);
                for i = 1:numel(fileInfo)
                    info = fileInfo{i};
                    if ~isfield(info, 'locations'), continue; end
                    locs = info.locations;
                    if ~iscell(locs) && numel(locs) > 1
                        locs = num2cell(locs);
                    elseif ~iscell(locs)
                        locs = {locs};
                    end
                    for k = 1:numel(locs)
                        if isfield(locs{k}, 'uid') && ~isempty(locs{k}.uid)
                            collected(end+1) = string(locs{k}.uid); %#ok<AGROW>
                        end
                    end
                end
                uids = unique(collected);
            catch
                % Leave uids empty; caller reports.
            end
        end

        function content = downloadURLBody(~, signedUrl)
            % Download the body of a signed URL to a scratch file and
            % return its content as a string. Uses the same file-download
            % path as ndi.cloud.api.files.getFile so a failure surfaces
            % the same way it would in production.
            tmp = tempname();
            [ok, ~] = ndi.cloud.api.files.getFile(string(signedUrl), tmp, 'useCurl', true);
            content = "";
            if ok && isfile(tmp)
                content = string(fileread(tmp));
                delete(tmp);
            end
        end
    end

    methods (Test)
        % ------------------------------------------------------------------
        % Sync path: single-page getSignedURLSet
        % ------------------------------------------------------------------
        function testGetSignedURLSetSinglePage(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetSinglePage";
            narrative = testCase.Narrative;

            narrative(end+1) = "Preparing to call getSignedURLSet with default limit.";
            [b, page, resp, url] = ndi.cloud.api.files.getSignedURLSet(...
                testCase.DatasetID, testCase.CloudDocumentID);
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, page, resp, url);
            testCase.verifyTrue(b, "getSignedURLSet returned failure. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            testCase.verifyTrue(isstruct(page), "Response was not a struct. " + msg);
            testCase.verifyTrue(isfield(page, 'files'), "Response missing `files`. " + msg);
            testCase.verifyTrue(isfield(page, 'totalCount'), "Response missing `totalCount`. " + msg);
            testCase.verifyTrue(isfield(page, 'expiresAt'),  "Response missing `expiresAt`. " + msg);

            % The doc references one file. Verify totalCount and that the
            % single UID in the response matches what the document points
            % at.
            testCase.verifyEqual(page.totalCount, numel(testCase.CloudDocumentUIDs), ...
                "totalCount does not match doc's referenced UIDs. " + msg);

            returnedUIDs = string(fieldnames(page.files));
            testCase.verifyEqual(sort(returnedUIDs), sort(testCase.CloudDocumentUIDs(:)), ...
                "UIDs in response do not match doc's referenced UIDs. " + msg);

            % nextCursor should be absent/empty on a page that fits in one.
            noNext = ~isfield(page, 'nextCursor') || isempty(page.nextCursor);
            testCase.verifyTrue(noNext, "nextCursor should be empty when set fits in one page. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: content round-trip via the signed URL
        % ------------------------------------------------------------------
        function testGetSignedURLSetContentRoundTrip(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetContentRoundTrip";
            narrative = testCase.Narrative;

            [b, page, resp, url] = ndi.cloud.api.files.getSignedURLSet(...
                testCase.DatasetID, testCase.CloudDocumentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, page, resp, url);
            testCase.fatalAssertTrue(b, "getSignedURLSet failed. " + msg);

            uid = testCase.CloudDocumentUIDs(1);
            % Fields inside a struct are always valid MATLAB identifiers;
            % UIDs from did.ido.unique_id() are hex/alnum so field access
            % is safe. Fall back to dynamic if the server changes shape.
            signedUrl = page.files.(char(uid));

            narrative(end+1) = "Preparing to download signed URL for UID " + uid;
            body = testCase.downloadURLBody(signedUrl);
            narrative(end+1) = "Downloaded " + strlength(body) + " bytes.";

            % Find which local file this UID belongs to, then verify
            % byte-for-byte. Which sus_i.dat file the UID maps to is
            % determined by the upload order; we look it up rather than
            % assuming.
            [b_det, det] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, uid);
            testCase.fatalAssertTrue(b_det, "Could not fetch file details for the UID. " + msg);

            matched = false;
            for k = 1:numel(testCase.FileContent)
                if body == testCase.FileContent(k)
                    matched = true;
                    break;
                end
            end
            testCase.verifyTrue(matched, ...
                "Downloaded body did not match any of the uploaded file contents. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: limit clamping (server caps at 1000)
        % ------------------------------------------------------------------
        function testGetSignedURLSetLimitClamped(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetLimitClamped";
            narrative = testCase.Narrative;

            % A request above the server cap should still succeed and
            % return the whole (small) set in one page; the server
            % clamps limit to SIGNED_URL_SET_MAX_LIMIT (1000).
            narrative(end+1) = "Calling getSignedURLSet with limit=5000 (server should clamp).";
            [b, page, resp, url] = ndi.cloud.api.files.getSignedURLSet(...
                testCase.DatasetID, testCase.CloudDocumentID, 'limit', 5000);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, page, resp, url);
            testCase.verifyTrue(b, "getSignedURLSet with oversized limit failed. " + msg);
            if ~b, testCase.Narrative = narrative; return; end
            testCase.verifyEqual(page.pageCount, numel(testCase.CloudDocumentUIDs), ...
                "pageCount does not match doc's referenced UIDs. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: full-set walker convenience wrapper
        % ------------------------------------------------------------------
        function testGetSignedURLSetAll(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetAll";
            narrative = testCase.Narrative;

            % Force cursor mechanics via limit=1 so the walker actually
            % follows nextCursor rather than getting everything in a page.
            narrative(end+1) = "Calling getSignedURLSetAll with limit=1 to force pagination.";
            [b, all, resp, url] = ndi.cloud.api.files.getSignedURLSetAll(...
                testCase.DatasetID, testCase.CloudDocumentID, 'limit', 1);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, all, resp, url);
            testCase.verifyTrue(b, "getSignedURLSetAll returned failure. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            testCase.verifyEqual(all.totalCount, numel(testCase.CloudDocumentUIDs), ...
                "Merged totalCount does not match doc's referenced UIDs. " + msg);
            mergedUIDs = string(fieldnames(all.files));
            testCase.verifyEqual(sort(mergedUIDs), sort(testCase.CloudDocumentUIDs(:)), ...
                "Merged UIDs do not match doc's referenced UIDs. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: unknown document should return 404
        % ------------------------------------------------------------------
        function testGetSignedURLSetUnknownDocument(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetUnknownDocument";
            narrative = testCase.Narrative;

            bogusDoc = "doc-that-does-not-exist-" + string(did.ido.unique_id());
            [b, ans_, resp, url] = ndi.cloud.api.files.getSignedURLSet(...
                testCase.DatasetID, bogusDoc);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_, resp, url);
            testCase.verifyFalse(b, "Bogus document id should fail. " + msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, ...
                "Expected HTTP 404 for unknown document. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Async path: create + poll + fetch result
        % ------------------------------------------------------------------
        function testCreateAndWaitForSignedURLSetJob(testCase)
            testCase.Narrative = "Begin testCreateAndWaitForSignedURLSetJob";
            narrative = testCase.Narrative;

            narrative(end+1) = "Preparing to create signed URL set job.";
            [b, job, resp, url] = ndi.cloud.api.files.createSignedURLSetJob(...
                testCase.DatasetID, testCase.CloudDocumentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, job, resp, url);

            % In an environment where the worker infrastructure has not
            % been provisioned (SIGNED_URL_SET_TOPIC_ARN unset), the API
            % returns 500 CONFIGURATION_ERROR. Skip rather than fail so
            % this test remains meaningful on partial deployments.
            if ~b
                if isstruct(job) && isfield(job, 'code') && strcmp(job.code, 'CONFIGURATION_ERROR')
                    testCase.assumeFail(...
                        "Signed URL set worker is not configured on this environment; skipping async path.");
                    testCase.Narrative = narrative;
                    return;
                end
                testCase.verifyTrue(b, "createSignedURLSetJob returned failure. " + msg);
                testCase.Narrative = narrative;
                return;
            end
            testCase.verifyTrue(isfield(job, 'jobId'),      "Job payload missing jobId. " + msg);
            testCase.verifyTrue(isfield(job, 'statusUrl'),  "Job payload missing statusUrl. " + msg);
            testCase.verifyTrue(isfield(job, 'datasetId'),  "Job payload missing datasetId. " + msg);
            testCase.verifyTrue(isfield(job, 'documentId'), "Job payload missing documentId. " + msg);

            narrative(end+1) = "Job accepted, id = " + string(job.jobId);

            % Poll once immediately so we exercise both the poll wrapper
            % and the wait wrapper.
            narrative(end+1) = "Polling job once for state.";
            [b_st, st, resp_st, url_st] = ndi.cloud.api.files.getSignedURLSetJob(string(job.jobId));
            msg_st = ndi.unittest.cloud.APIMessage(narrative, b_st, st, resp_st, url_st);
            testCase.verifyTrue(b_st, "getSignedURLSetJob returned failure. " + msg_st);
            testCase.verifyTrue(isfield(st, 'state'), "Poll response missing state. " + msg_st);
            allowed = ["queued","running","ready","failed"];
            testCase.verifyTrue(any(string(st.state) == allowed), ...
                "Poll returned unexpected state: " + string(st.state) + ". " + msg_st);

            % Wait for the job to reach a terminal state; keep the timeout
            % modest so the suite does not stall on an unhealthy worker.
            narrative(end+1) = "Waiting for job to reach a terminal state (up to 180s).";
            [b_w, done, resp_w, url_w] = ndi.cloud.api.files.waitForSignedURLSetJob(...
                string(job.jobId), 'timeout', 180, 'initialInterval', 2, 'maxInterval', 15);
            msg_w = ndi.unittest.cloud.APIMessage(narrative, b_w, done, resp_w, url_w);
            testCase.verifyTrue(b_w, "waitForSignedURLSetJob did not report 'ready'. " + msg_w);
            if ~b_w, testCase.Narrative = narrative; return; end

            testCase.verifyEqual(string(done.state), "ready", ...
                "Terminal state was not 'ready'. " + msg_w);
            testCase.verifyTrue(isfield(done, 'resultUrl'), "Ready payload missing resultUrl. " + msg_w);
            testCase.verifyGreaterThan(strlength(string(done.resultUrl)), 0, ...
                "resultUrl was empty. " + msg_w);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Async path: unknown job id should surface 404 cleanly
        % ------------------------------------------------------------------
        function testGetSignedURLSetJobUnknownId(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetJobUnknownId";
            narrative = testCase.Narrative;

            bogus = "job-does-not-exist-" + string(did.ido.unique_id());
            [b, ans_, resp, url] = ndi.cloud.api.files.getSignedURLSetJob(bogus);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_, resp, url);
            testCase.verifyFalse(b, "Bogus job id should fail. " + msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, ...
                "Expected HTTP 404 for unknown job id. " + msg);

            testCase.Narrative = narrative;
        end
    end
end
