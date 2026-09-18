classdef FileTierTest < matlab.unittest.TestCase
% FileTierTest - Test suite for the ndi.cloud.api.files file-tier commands.
%
%   Exercises the client wrappers around the two new server endpoints:
%
%     POST /datasets/{d}/file-tier-jobs
%     GET  /file-tier-jobs/{jobId}
%
%   The setup mirrors SignedURLSetTest: build a small local ndi.dataset
%   with a handful of generic_file documents, push it to a fresh cloud
%   dataset via ndi.cloud.uploadDataset, wait for the server-side bulk
%   extraction to settle, then run the tier commands against one of the
%   uploaded documents.
%
%   The target tier for the happy-path test is PSEUDO_COLD. It skips S3
%   entirely and is server-side-only accepted in non-production stages,
%   so the round-trip is fast and pays no S3 minimum-storage charges.
%
%   Each test follows the narrative + APIMessage pattern used throughout
%   ndi.unittest.cloud so a failure carries every step and the URL of the
%   last API call.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_FILE_TIER_';
        NumFiles = 2;
    end

    properties
        DatasetID       (1,1) string = missing
        LocalDataset
        Narrative       (1,:) string
        FileUIDs        (1,:) string
        CloudDocumentID (1,1) string = missing  % cloud id of file_tier_doc_1
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
            % dataset.
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));

            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.LocalDataset = ndi.dataset.dir('test_ds', tempFolder.Folder);

            doc_target = ndi.document('base', ...
                'base.name', 'file_tier_target', ...
                'base.session_id', testCase.LocalDataset.id());
            testCase.LocalDataset.database_add(doc_target);

            for i = 1:testCase.NumFiles
                localPath = fullfile(tempFolder.Folder, sprintf('ft_%d.dat', i));
                fid = fopen(localPath, 'w');
                fprintf(fid, 'file-tier content #%d %s', i, char(did.ido.unique_id()));
                fclose(fid);

                docI = ndi.document('generic_file', ...
                    'base.name', sprintf('file_tier_doc_%d', i), ...
                    'generic_file.filename', sprintf('ft_%d.dat', i), ...
                    'generic_file.dateCreated', 0, ...
                    'generic_file.dateUpdated', 0, ...
                    'base.session_id', testCase.LocalDataset.id());
                docI = docI.add_file('generic_file.ext', localPath);
                docI = docI.set_dependency_value('document_id', doc_target.id(), 'ErrorIfNotFound', 0);
                testCase.LocalDataset.database_add(docI);
            end

            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", unique_name));
            testCase.assertTrue(b, "Failed to create cloud dataset for FileTierTest.");
            testCase.DatasetID = cloudId;
            testCase.addTeardown(@() testCase.cleanupCloudDataset());

            remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, testCase.LocalDataset);
            testCase.LocalDataset.database_add(remoteDoc);

            success_upload = ndi.cloud.uploadDataset(testCase.LocalDataset);
            testCase.assertTrue(success_upload, "Failed to upload test dataset to cloud.");
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            [b_files, files_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            testCase.assertTrue(b_files, "listFiles failed after upload.");
            testCase.FileUIDs = string({files_list.uid});
            testCase.assertEqual(numel(testCase.FileUIDs), testCase.NumFiles, ...
                "Dataset did not report the expected number of uploaded files.");

            [b_docs, docs_list] = ndi.cloud.api.documents.listDatasetDocumentsAll(...
                testCase.DatasetID, 'checkForUpdates', true);
            testCase.assertTrue(b_docs, "listDatasetDocumentsAll failed.");
            cloudId1 = testCase.findCloudDocID(docs_list, 'file_tier_doc_1');
            testCase.assertFalse(ismissing(cloudId1), ...
                "Could not find cloud id for local doc file_tier_doc_1.");
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
    end

    methods (Test)
        % ------------------------------------------------------------------
        % Happy path: submit, poll once, wait for terminal state.
        % PSEUDO_COLD skips S3 -- meant to be fast on dev.
        % ------------------------------------------------------------------
        function testCreateAndWaitForFileTierJob(testCase)
            testCase.Narrative = "Begin testCreateAndWaitForFileTierJob";
            narrative = testCase.Narrative;

            narrative(end+1) = "Preparing to call setFileTier with PSEUDO_COLD.";
            [b, job, resp, url] = ndi.cloud.api.files.setFileTier(...
                testCase.DatasetID, [testCase.CloudDocumentID], "PSEUDO_COLD");
            msg = ndi.unittest.cloud.APIMessage(narrative, b, job, resp, url);

            % A partial deployment on this dev stage would surface as a
            % 500 CONFIGURATION_ERROR / ENQUEUE_ERROR / JOB_CREATION_ERROR,
            % or reject PSEUDO_COLD because the stage is treated as
            % production. Skip rather than fail so the test stays
            % meaningful on those.
            if ~b
                if isstruct(job) && isfield(job, 'code') && ...
                        any(strcmp(job.code, {'CONFIGURATION_ERROR','ENQUEUE_ERROR', ...
                                              'JOB_CREATION_ERROR','INVALID_TARGET_TIER'}))
                    testCase.assumeFail(...
                        "File-tier endpoint not fully configured for PSEUDO_COLD on this environment; skipping. " + msg);
                    testCase.Narrative = narrative;
                    return;
                end
                testCase.verifyTrue(b, "setFileTier returned failure. " + msg);
                testCase.Narrative = narrative;
                return;
            end

            testCase.verifyTrue(isfield(job, 'jobId'), "setFileTier payload missing jobId. " + msg);
            testCase.verifyTrue(isfield(job, 'fileCount'), "setFileTier payload missing fileCount. " + msg);
            testCase.verifyTrue(isfield(job, 'resolvedDocumentCount'), ...
                "setFileTier payload missing resolvedDocumentCount. " + msg);
            testCase.verifyTrue(isfield(job, 'collateralDocumentIds'), ...
                "setFileTier payload missing collateralDocumentIds. " + msg);
            testCase.verifyGreaterThanOrEqual(job.fileCount, 1, ...
                "fileCount should be at least 1 for a doc with one attached file. " + msg);

            narrative(end+1) = "Job accepted, id = " + string(job.jobId);

            narrative(end+1) = "Polling job once for state.";
            [b_st, st, resp_st, url_st] = ndi.cloud.api.files.getFileTierJob(string(job.jobId));
            msg_st = ndi.unittest.cloud.APIMessage(narrative, b_st, st, resp_st, url_st);
            testCase.verifyTrue(b_st, "getFileTierJob returned failure. " + msg_st);
            testCase.verifyTrue(isfield(st, 'state'), "Poll response missing state. " + msg_st);
            % v1 runs the worker inline (setImmediate), so the job may
            % already be terminal by the time we poll; every non-terminal
            % and terminal state is a legal first read.
            allowed = ["queued","running","completed","failed","superseded"];
            testCase.verifyTrue(any(string(st.state) == allowed), ...
                "Poll returned unexpected state: " + string(st.state) + ". " + msg_st);
            testCase.verifyEqual(string(st.targetTier), "PSEUDO_COLD", ...
                "Poll response targetTier did not round-trip. " + msg_st);

            narrative(end+1) = "Waiting for job to reach a terminal state (up to 60s).";
            [b_w, done, resp_w, url_w] = ndi.cloud.api.files.waitForFileTierJob(...
                string(job.jobId), 'timeout', 60, 'initialInterval', 1, 'maxInterval', 5);
            msg_w = ndi.unittest.cloud.APIMessage(narrative, b_w, done, resp_w, url_w);
            testCase.verifyTrue(b_w, "waitForFileTierJob did not report 'completed'. " + msg_w);
            if ~b_w, testCase.Narrative = narrative; return; end

            testCase.verifyEqual(string(done.state), "completed", ...
                "Terminal state was not 'completed'. " + msg_w);
            if isfield(done, 'filesDone')
                testCase.verifyEqual(done.filesDone, job.fileCount, ...
                    "filesDone should match the fileCount submitted. " + msg_w);
            end
            if isfield(done, 'filesFailed')
                testCase.verifyEqual(done.filesFailed, 0, ...
                    "filesFailed should be 0 on a completed PSEUDO_COLD job. " + msg_w);
            end

            % Read the doc's cached summary back and confirm the freeze
            % actually shows up there. This is the read path a caller uses
            % to answer "what tier is this doc on now?" without polling
            % the job again.
            narrative(end+1) = "Reading tier summary back via getFileTier.";
            [b_r, tier, resp_r, url_r] = ndi.cloud.api.files.getFileTier(...
                testCase.DatasetID, testCase.CloudDocumentID);
            msg_r = ndi.unittest.cloud.APIMessage(narrative, b_r, tier, resp_r, url_r);
            testCase.verifyTrue(b_r, "getFileTier returned failure. " + msg_r);
            testCase.verifyEqual(tier.dominant, "PSEUDO_COLD", ...
                "getFileTier.dominant did not reflect the completed freeze. " + msg_r);
            testCase.verifyTrue(isstruct(tier.counts) || isa(tier.counts, 'containers.Map'), ...
                "getFileTier.counts is not a struct or Map. " + msg_r);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % getFileTier on a doc that has never had a tier op should read
        % cleanly and return an empty/default summary rather than throw.
        % ------------------------------------------------------------------
        function testGetFileTierOnUntieredDocumentReturnsEmpty(testCase)
            testCase.Narrative = "Begin testGetFileTierOnUntieredDocumentReturnsEmpty";
            narrative = testCase.Narrative;

            narrative(end+1) = "Reading getFileTier on a fresh doc (no prior tier op).";
            [b, tier, resp, url] = ndi.cloud.api.files.getFileTier(...
                testCase.DatasetID, testCase.CloudDocumentID);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, tier, resp, url);
            testCase.verifyTrue(b, "getFileTier failed on fresh doc. " + msg);
            testCase.verifyTrue(isstruct(tier), "getFileTier answer is not a struct. " + msg);
            % A doc with no tier state should read as "" dominant (or empty
            % counts). The wrapper normalizes an absent server field to
            % an empty projection, so this is a shape assertion, not a
            % server-guarantee assertion.
            testCase.verifyTrue(tier.dominant == "" || tier.dominant == "STANDARD", ...
                "Fresh doc dominant should be empty or STANDARD, got: " + tier.dominant + ". " + msg);

            testCase.Narrative = narrative;
        end

        % ------------------------------------------------------------------
        % Unknown job id should surface 404.
        % ------------------------------------------------------------------
        function testGetFileTierJobUnknownId(testCase)
            testCase.Narrative = "Begin testGetFileTierJobUnknownId";
            narrative = testCase.Narrative;

            bogus = "job-does-not-exist-" + string(did.ido.unique_id());
            [b, ans_, resp, url] = ndi.cloud.api.files.getFileTierJob(bogus);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_, resp, url);
            testCase.verifyFalse(b, "Bogus job id should fail. " + msg);
            testCase.verifyEqual(double(resp.StatusCode), 404, ...
                "Expected HTTP 404 for unknown job id. " + msg);

            testCase.Narrative = narrative;
        end
    end
end
