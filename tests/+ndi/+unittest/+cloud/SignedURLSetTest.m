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
%   test reads the files back.
%
%   The setup deliberately keeps its assertions non-fatal so a failure in
%   one method's setup does not abort the whole run; it also does not try
%   to pre-parse the cloud document's file references. Each test derives
%   its expectations from the API response under test, and cross-checks
%   returned UIDs against ndi.cloud.api.files.listFiles (well-tested).
%
%   Each test follows the narrative + APIMessage pattern used throughout
%   ndi.unittest.cloud so a failure carries every step and the URL of the
%   last API call.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_SIGNED_URL_SET_';
        NumFiles = 4;
    end

    properties
        DatasetID       (1,1) string = missing
        LocalDataset
        Narrative       (1,:) string
        FileUIDs        (1,:) string  % dataset's uploaded file UIDs
        FileContent     (1,:) string  % content strings written to the local files
        CloudDocumentID (1,1) string = missing  % cloud id of signed_url_set_doc_1
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
            % Non-fatal by design: a failure here fails only this method's
            % setup, letting subsequent methods still try their own fresh
            % dataset. That is why every assert below is a regular
            % assertTrue rather than a fatalAssertTrue.
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));

            % 1. Local dataset with N generic_file documents, each with
            %    one file. All hang off a base 'test_target' document.
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

            % 2. Create cloud dataset and link.
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", unique_name));
            testCase.assertTrue(b, "Failed to create cloud dataset for SignedURLSetTest.");
            testCase.DatasetID = cloudId;
            testCase.addTeardown(@() testCase.cleanupCloudDataset());

            remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, testCase.LocalDataset);
            testCase.LocalDataset.database_add(remoteDoc);

            % 3. Upload, then wait for server-side extraction.
            success_upload = ndi.cloud.uploadDataset(testCase.LocalDataset);
            testCase.assertTrue(success_upload, "Failed to upload test dataset to cloud.");
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            % 4. Record dataset-level uploaded UIDs. Any UID returned by
            %    getSignedURLSet must be in this set.
            [b_files, files_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            testCase.assertTrue(b_files, "listFiles failed after upload.");
            testCase.FileUIDs = string({files_list.uid});
            testCase.assertEqual(numel(testCase.FileUIDs), testCase.NumFiles, ...
                "Dataset did not report the expected number of uploaded files.");

            % 5. Look up the cloud id of signed_url_set_doc_1 by matching
            %    ndiId against the local document's id. We do NOT try to
            %    pre-parse data.files.file_info here; each test asks the
            %    endpoint under test what it sees and verifies against
            %    that.
            [b_docs, docs_list] = ndi.cloud.api.documents.listDatasetDocumentsAll(...
                testCase.DatasetID, 'checkForUpdates', true);
            testCase.assertTrue(b_docs, "listDatasetDocumentsAll failed.");

            cloudId1 = testCase.findCloudDocID(docs_list, 'signed_url_set_doc_1');
            testCase.assertFalse(ismissing(cloudId1), ...
                "Could not find cloud id for local doc signed_url_set_doc_1.");
            testCase.CloudDocumentID = cloudId1;
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

        function cloudId = findCloudDocID(testCase, docs_list, localName)
            % Find a cloud document by base.name -> cloud id.
            cloudId = string(missing);
            q = ndi.query('base.name', 'exact_string', localName);
            localDocs = testCase.LocalDataset.database_search(q);
            if numel(localDocs) ~= 1, return; end
            localId = localDocs{1}.id();
            for i = 1:numel(docs_list)
                if isfield(docs_list(i), 'ndiId') && strcmp(docs_list(i).ndiId, localId)
                    cloudId = string(docs_list(i).id);
                    return;
                end
            end
        end

        function body = downloadURLBody(~, signedUrl)
            % Download the body of a signed URL to a scratch file and
            % return its content as a string. Uses ndi.cloud.api.files.getFile
            % so a failure surfaces the same way it would in production.
            tmp = tempname();
            [ok, ~] = ndi.cloud.api.files.getFile(string(signedUrl), tmp, 'useCurl', true);
            body = "";
            if ok && isfile(tmp)
                body = string(fileread(tmp));
                delete(tmp);
            end
        end

        function matched = anyContentMatches(testCase, body)
            % True iff body equals any of the uploaded file contents.
            matched = false;
            for k = 1:numel(testCase.FileContent)
                if body == testCase.FileContent(k)
                    matched = true;
                    return;
                end
            end
        end
    end

    methods (Static, Access = private)
        function uids = normalizeReturnedUIDs(filesStruct)
            % jsondecode prepends an 'x' to any JSON object key that isn't
            % a valid MATLAB identifier -- and file UIDs start with a
            % digit, so every UID in the `files` map comes back with an
            % extra leading 'x'. Strip it back off so the returned UIDs
            % match what listFiles reports and what the server actually
            % signed. Keys that did NOT get an 'x' prefix (rare, but
            % possible if a UID ever begins with a letter) are left
            % alone.
            raw = string(fieldnames(filesStruct));
            uids = raw;
            for i = 1:numel(uids)
                s = char(uids(i));
                if ~isempty(s) && s(1) == 'x'
                    uids(i) = string(s(2:end));
                end
            end
        end

        function id = wellFormedButUnusedDocId()
            % Endpoint routes /:documentId through Mongoose findById, which
            % throws a CastError (surfacing as 500) on a non-24-hex-char
            % string. Use a well-formed but not-in-database id so the 404
            % path is what we actually exercise.
            hex = '0123456789abcdef';
            id = string(hex(randi(numel(hex), 1, 24)));
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
            testCase.verifyTrue(isfield(page, 'files'),      "Response missing `files`. " + msg);
            testCase.verifyTrue(isfield(page, 'totalCount'), "Response missing `totalCount`. " + msg);
            testCase.verifyTrue(isfield(page, 'expiresAt'),  "Response missing `expiresAt`. " + msg);

            % totalCount is however many of the doc's referenced UIDs
            % actually exist as uploaded files in the dataset. For a
            % generic_file doc, we expect exactly one, but if this
            % environment resolves fewer we still want a useful
            % diagnostic instead of a confusing equality failure.
            testCase.verifyGreaterThanOrEqual(page.totalCount, 1, ...
                "totalCount was 0; the endpoint could not resolve any file UID for this doc. " + msg);

            returnedUIDs = ndi.unittest.cloud.SignedURLSetTest.normalizeReturnedUIDs(page.files);
            testCase.verifyEqual(numel(returnedUIDs), page.totalCount, ...
                "files map has a different size than totalCount. " + msg);

            % Every returned UID must be one the dataset actually holds.
            for i = 1:numel(returnedUIDs)
                testCase.verifyTrue(ismember(returnedUIDs(i), testCase.FileUIDs), ...
                    "Returned UID " + returnedUIDs(i) + " is not in the dataset's uploaded files. " + msg);
            end

            % nextCursor should be absent/empty on a page that fits.
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
            testCase.assertTrue(b, "getSignedURLSet failed. " + msg);

            % Fieldnames still carry the 'x' prefix that jsondecode adds;
            % use the raw name to index into page.files but the stripped
            % form only for display / cross-checks.
            rawFieldNames = string(fieldnames(page.files));
            testCase.assertNotEmpty(rawFieldNames, ...
                "Endpoint returned an empty files map. " + msg);

            rawKey = char(rawFieldNames(1));
            signedUrl = page.files.(rawKey);

            narrative(end+1) = "Preparing to download signed URL for UID " + string(rawKey);
            body = testCase.downloadURLBody(signedUrl);
            narrative(end+1) = "Downloaded " + strlength(body) + " bytes.";

            testCase.verifyTrue(testCase.anyContentMatches(body), ...
                "Downloaded body did not match any of the uploaded file contents. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: oversized limit is server-clamped
        % ------------------------------------------------------------------
        function testGetSignedURLSetLimitClamped(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetLimitClamped";
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling getSignedURLSet with limit=5000 (server should clamp to 1000).";
            [b, page, resp, url] = ndi.cloud.api.files.getSignedURLSet(...
                testCase.DatasetID, testCase.CloudDocumentID, 'limit', 5000);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, page, resp, url);
            testCase.verifyTrue(b, "getSignedURLSet with oversized limit failed. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            testCase.verifyTrue(isfield(page, 'pageCount'), "Response missing `pageCount`. " + msg);
            testCase.verifyEqual(page.pageCount, page.totalCount, ...
                "pageCount should equal totalCount when limit >> totalCount. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: full-set walker convenience wrapper
        % ------------------------------------------------------------------
        function testGetSignedURLSetAll(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetAll";
            narrative = testCase.Narrative;

            % limit=1 forces the walker to loop even for a single-file
            % doc: the first page carries one file and no nextCursor
            % (since 1/1 = last), so the walker terminates cleanly.
            narrative(end+1) = "Calling getSignedURLSetAll with limit=1.";
            [b, all, resp, url] = ndi.cloud.api.files.getSignedURLSetAll(...
                testCase.DatasetID, testCase.CloudDocumentID, 'limit', 1);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, all, resp, url);
            testCase.verifyTrue(b, "getSignedURLSetAll returned failure. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            testCase.verifyGreaterThanOrEqual(all.pages, 1, "Walker reported 0 pages. " + msg);
            testCase.verifyEqual(all.pageCount, all.totalCount, ...
                "Merged pageCount does not match totalCount. " + msg);

            mergedUIDs = ndi.unittest.cloud.SignedURLSetTest.normalizeReturnedUIDs(all.files);
            for i = 1:numel(mergedUIDs)
                testCase.verifyTrue(ismember(mergedUIDs(i), testCase.FileUIDs), ...
                    "Merged UID " + mergedUIDs(i) + " is not in the dataset's uploaded files. " + msg);
            end

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Sync path: unknown document should return 404
        % ------------------------------------------------------------------
        function testGetSignedURLSetUnknownDocument(testCase)
            testCase.Narrative = "Begin testGetSignedURLSetUnknownDocument";
            narrative = testCase.Narrative;

            bogusDoc = ndi.unittest.cloud.SignedURLSetTest.wellFormedButUnusedDocId();
            [b, ans_, resp, url] = ndi.cloud.api.files.getSignedURLSet(...
                testCase.DatasetID, bogusDoc);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_, resp, url);
            testCase.verifyFalse(b, "Bogus document id should fail. " + msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, ...
                "Expected HTTP 404 for unknown (but well-formed) document id. " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Async path: create + poll + wait for result
        % ------------------------------------------------------------------
        function testCreateAndWaitForSignedURLSetJob(testCase)
            testCase.Narrative = "Begin testCreateAndWaitForSignedURLSetJob";
            narrative = testCase.Narrative;

            narrative(end+1) = "Preparing to create signed URL set job.";
            [b, job, resp, url] = ndi.cloud.api.files.createSignedURLSetJob(...
                testCase.DatasetID, testCase.CloudDocumentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, job, resp, url);

            % Environments where the worker isn't provisioned return
            % 500 CONFIGURATION_ERROR / ENQUEUE_ERROR / JOB_CREATION_ERROR.
            % Skip rather than fail so this test stays meaningful on
            % partial deployments.
            if ~b
                if isstruct(job) && isfield(job, 'code') && ...
                        any(strcmp(job.code, {'CONFIGURATION_ERROR','ENQUEUE_ERROR','JOB_CREATION_ERROR'}))
                    testCase.assumeFail(...
                        "Signed URL set worker is not configured on this environment; skipping async path. " + msg);
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

            narrative(end+1) = "Polling job once for state.";
            [b_st, st, resp_st, url_st] = ndi.cloud.api.files.getSignedURLSetJob(string(job.jobId));
            msg_st = ndi.unittest.cloud.APIMessage(narrative, b_st, st, resp_st, url_st);
            testCase.verifyTrue(b_st, "getSignedURLSetJob returned failure. " + msg_st);
            testCase.verifyTrue(isfield(st, 'state'), "Poll response missing state. " + msg_st);
            allowed = ["queued","running","ready","failed"];
            testCase.verifyTrue(any(string(st.state) == allowed), ...
                "Poll returned unexpected state: " + string(st.state) + ". " + msg_st);

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
        % Async path: unknown job id should surface 404
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
