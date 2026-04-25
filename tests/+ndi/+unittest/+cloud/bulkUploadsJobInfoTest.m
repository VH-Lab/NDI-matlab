classdef bulkUploadsJobInfoTest < matlab.unittest.TestCase
% bulkUploadsJobInfoTest - Test suite for the bulk-upload job info API.
%
%   Exercises every facet of the three new client calls:
%     ndi.cloud.api.files.getBulkUploadStatus
%     ndi.cloud.api.files.listActiveBulkUploads
%     ndi.cloud.api.files.waitForBulkUpload
%
%   Each test method follows the narrative + APIMessage pattern used
%   throughout ndi.unittest.cloud, so on failure the diagnostic includes
%   every step that was attempted and the URL of the last API call --
%   useful even for backend developers who don't run MATLAB.
%
%   Each TestMethodSetup creates a fresh cloud dataset and the matching
%   teardown deletes it, so the tests are isolated from each other and
%   from any concurrent activity on the same account.
%

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_BULK_JOBINFO_';
        AllowedStates = ["queued","extracting","complete","failed"];
        AllStateFilters = ["active","all","queued","extracting","complete","failed"];
    end

    properties
        DatasetID (1,1) string = missing
        Narrative (1,:) string
        KeepDataset (1,1) logical = false
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set. This is not an API problem.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set. This is not an API problem.');
        end
    end

    methods (TestMethodSetup)
        function setupNewDataset(testCase)
            testCase.KeepDataset = false;
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);

            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);
            if ~b
                setup_narrative = "TestMethodSetup: Failed to create temporary dataset " + unique_name;
                msg = ndi.unittest.cloud.APIMessage(setup_narrative, b, cloudDatasetID, resp, url);
                testCase.fatalAssertTrue(b, "Failed to create dataset in TestMethodSetup. " + msg);
            end
            testCase.DatasetID = cloudDatasetID;
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
        end
    end

    methods (Access = private)
        function deleteDatasetAfterTest(testCase)
            if testCase.KeepDataset
                narrative = testCase.Narrative;
                narrative(end+1) = "TEARDOWN SKIPPED: Preserving dataset for inspection.";
                testCase.Narrative = narrative;
                return;
            end
            if ~ismissing(testCase.DatasetID)
                narrative = testCase.Narrative;
                narrative(end+1) = "TEARDOWN: Pausing before delete to let backend converge on any recent uploads.";
                pause(5);
                narrative(end+1) = "TEARDOWN: Deleting temporary dataset ID: " + testCase.DatasetID;
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
                if ~b
                    narrative(end+1) = "TEARDOWN: First delete attempt failed; waiting and retrying once.";
                    pause(15);
                    [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
                end
                if ~b
                    msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_del, resp_del, url_del);
                    testCase.assertTrue(b, "Failed to delete dataset in TestMethodTeardown. " + msg);
                end
            end
        end

        function [tempFolder, zipFilePath, fileUIDs] = makeSmallZip(testCase, numFiles)
            % Build a tiny zip archive on disk and return its path. The zip
            % is named with the dataset id as a prefix because the bulk
            % upload S3 trigger relies on that convention.
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUIDs = strings(1, numFiles);
            localFilePaths = strings(1, numFiles);
            for i = 1:numFiles
                fileUIDs(i) = string(did.ido.unique_id());
                localFilePaths(i) = fullfile(tempFolder.Folder, fileUIDs(i));
                fid = fopen(localFilePaths(i), 'w');
                fwrite(fid, uint8(randi([0 255], 1, 32)), 'uint8');
                fclose(fid);
            end
            zipFileName = testCase.DatasetID + "." + string(did.ido.unique_id()) + ".zip";
            zipFilePath = fullfile(tempFolder.Folder, zipFileName);
            zip(zipFilePath, localFilePaths);
            assert(isfile(zipFilePath), 'Zip archive must exist after creation');
        end
    end

    methods (Access = private)
        function [info, urlMsg] = createBulkJob(testCase, narrative)
            % Provision a fresh BulkUploadJob server-side (state='queued')
            % by asking for a bulk upload URL. Returns the {url, jobId}
            % info struct and the APIMessage formatted from the call.
            [b_url, info, resp_url, url_url] = ndi.cloud.api.files.getFileCollectionUploadURL(testCase.DatasetID);
            urlMsg = ndi.unittest.cloud.APIMessage(narrative, b_url, info, resp_url, url_url);
            testCase.fatalAssertTrue(b_url, "Failed to get bulk upload URL in helper. " + urlMsg);
            testCase.fatalAssertTrue(isfield(info, 'jobId') && strlength(string(info.jobId)) > 0, ...
                "Bulk upload response must contain a non-empty jobId. " + urlMsg);
        end
    end

    methods (Test)

        function testListActiveBulkUploadsForFreshDatasetIsEmpty(testCase)
            % A freshly created dataset has no bulk-upload jobs yet, so
            % listActiveBulkUploads with the default state='active' filter
            % must return an empty jobs array.
            testCase.Narrative = "Begin testListActiveBulkUploadsForFreshDatasetIsEmpty";
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling listActiveBulkUploads on a brand-new dataset (no uploads yet).";
            [b, ans_list, resp, url] = ndi.cloud.api.files.listActiveBulkUploads(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_list, resp, url);
            testCase.verifyTrue(b, "listActiveBulkUploads call failed on fresh dataset. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            narrative(end+1) = "Testing: response is a struct containing a 'jobs' field.";
            testCase.verifyTrue(isstruct(ans_list) && isfield(ans_list, 'jobs'), ...
                "listActiveBulkUploads response missing 'jobs' field on fresh dataset. " + msg);

            narrative(end+1) = "Testing: response 'datasetId' echoes the requested dataset.";
            testCase.verifyTrue(isfield(ans_list, 'datasetId') && string(ans_list.datasetId) == testCase.DatasetID, ...
                "listActiveBulkUploads returned an unexpected 'datasetId'. " + msg);

            narrative(end+1) = "Testing: 'jobs' array is empty (no uploads have happened on this dataset).";
            testCase.verifyEmpty(ans_list.jobs, ...
                "Fresh dataset reported one or more active bulk-upload jobs. " + msg);

            testCase.Narrative = narrative;
        end

        function testGetBulkUploadStatusForUnknownJobIdFails(testCase)
            % An unknown jobId must NOT return a 200 OK with a status
            % struct. The server should respond with an error status. The
            % wrapper translates that into b=false.
            testCase.Narrative = "Begin testGetBulkUploadStatusForUnknownJobIdFails";
            narrative = testCase.Narrative;

            bogusJobId = "no-such-job-" + string(did.ido.unique_id());
            narrative(end+1) = "Calling getBulkUploadStatus with a fabricated jobId: " + bogusJobId;
            [b, ans_status, resp, url] = ndi.cloud.api.files.getBulkUploadStatus(bogusJobId);
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_status, resp, url);
            narrative(end+1) = "Testing: API call must report failure for an unknown jobId.";
            testCase.verifyFalse(b, "getBulkUploadStatus unexpectedly succeeded for an unknown jobId. " + msg);

            testCase.Narrative = narrative;
        end

        function testGetBulkUploadStatusReturnsExpectedSchema(testCase)
            % Create a job (state='queued' immediately after URL provisioning),
            % then call getBulkUploadStatus and verify every documented
            % field of BulkUploadJobResponse is present and has a sensible
            % type.
            testCase.Narrative = "Begin testGetBulkUploadStatusReturnsExpectedSchema";
            narrative = testCase.Narrative;

            narrative(end+1) = "STEP 1: Provisioning a bulk upload URL to create a server-side BulkUploadJob row.";
            [info, ~] = testCase.createBulkJob(narrative);
            narrative(end+1) = "Job created with jobId=" + info.jobId + ".";

            narrative(end+1) = "STEP 2: Calling getBulkUploadStatus(jobId) immediately after provisioning.";
            [b, ans_status, resp, url] = ndi.cloud.api.files.getBulkUploadStatus(info.jobId);
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_status, resp, url);
            testCase.verifyTrue(b, "getBulkUploadStatus call failed for a freshly created job. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            narrative(end+1) = "Testing: response is a struct.";
            testCase.verifyTrue(isstruct(ans_status), "getBulkUploadStatus response is not a struct. " + msg);
            if ~isstruct(ans_status), testCase.Narrative = narrative; return; end

            % Schema check: every documented field must be present.
            requiredFields = ["jobId","datasetId","state","createdAt","filesExtracted"];
            for k = 1:numel(requiredFields)
                f = requiredFields(k);
                narrative(end+1) = "Testing: response contains '" + f + "' field.";
                testCase.verifyTrue(isfield(ans_status, char(f)), ...
                    "getBulkUploadStatus response is missing field '" + f + "'. " + msg);
            end

            narrative(end+1) = "Testing: returned 'jobId' equals the requested jobId.";
            testCase.verifyEqual(string(ans_status.jobId), info.jobId, ...
                "getBulkUploadStatus returned a different jobId than was requested. " + msg);

            narrative(end+1) = "Testing: returned 'datasetId' equals the test dataset.";
            testCase.verifyEqual(string(ans_status.datasetId), testCase.DatasetID, ...
                "getBulkUploadStatus returned an unexpected 'datasetId'. " + msg);

            narrative(end+1) = "Testing: 'state' is one of " + strjoin(testCase.AllowedStates, ", ") + ".";
            testCase.verifyTrue(ismember(string(ans_status.state), testCase.AllowedStates), ...
                "getBulkUploadStatus returned an unexpected 'state' value '" + string(ans_status.state) + "'. " + msg);

            narrative(end+1) = "Testing: 'filesExtracted' is a non-negative number.";
            testCase.verifyTrue(isnumeric(ans_status.filesExtracted) && ans_status.filesExtracted >= 0, ...
                "getBulkUploadStatus returned an invalid 'filesExtracted' value. " + msg);

            testCase.Narrative = narrative;
        end

        function testListActiveBulkUploadsIncludesProvisionedJob(testCase)
            % After calling getFileCollectionUploadURL, the new job should
            % show up in listActiveBulkUploads(state='active') because the
            % server inserts it in the 'queued' state.
            testCase.Narrative = "Begin testListActiveBulkUploadsIncludesProvisionedJob";
            narrative = testCase.Narrative;

            narrative(end+1) = "STEP 1: Provisioning a bulk upload URL (creates a queued job).";
            [info, ~] = testCase.createBulkJob(narrative);
            narrative(end+1) = "Job created with jobId=" + info.jobId + ".";

            narrative(end+1) = "STEP 2: Calling listActiveBulkUploads with default state='active'.";
            [b, ans_list, resp, url] = ndi.cloud.api.files.listActiveBulkUploads(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_list, resp, url);
            testCase.verifyTrue(b, "listActiveBulkUploads call failed. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            testCase.verifyTrue(isstruct(ans_list) && isfield(ans_list, 'jobs'), ...
                "listActiveBulkUploads response missing 'jobs' field. " + msg);
            if ~isfield(ans_list, 'jobs'), testCase.Narrative = narrative; return; end

            jobIds = strings(1, numel(ans_list.jobs));
            for k = 1:numel(ans_list.jobs)
                jobIds(k) = string(ans_list.jobs(k).jobId);
            end
            narrative(end+1) = "Testing: the freshly-provisioned jobId " + info.jobId + ...
                " appears in the active list (server returned " + strjoin(jobIds, ", ") + ").";
            testCase.verifyTrue(ismember(info.jobId, jobIds), ...
                "Provisioned bulk-upload job is not visible under state='active'. " + msg);

            testCase.Narrative = narrative;
        end

        function testListActiveBulkUploadsAcceptsAllValidStates(testCase)
            % Every documented state filter -- 'active', 'all', 'queued',
            % 'extracting', 'complete', 'failed' -- must be accepted by the
            % server and produce a structurally valid response.
            testCase.Narrative = "Begin testListActiveBulkUploadsAcceptsAllValidStates";
            narrative = testCase.Narrative;

            narrative(end+1) = "STEP 1: Provisioning a job so at least one filter (active/queued/all) yields a hit.";
            [info, ~] = testCase.createBulkJob(narrative);
            narrative(end+1) = "Job created with jobId=" + info.jobId + ".";

            for k = 1:numel(testCase.AllStateFilters)
                stateValue = testCase.AllStateFilters(k);
                narrative(end+1) = "STEP 2." + k + ": Calling listActiveBulkUploads with state='" + stateValue + "'.";
                [b, ans_list, resp, url] = ndi.cloud.api.files.listActiveBulkUploads(testCase.DatasetID, ...
                    'state', stateValue);
                narrative(end+1) = "  Attempted to call API with URL " + string(url);
                msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_list, resp, url);
                testCase.verifyTrue(b, "listActiveBulkUploads(state='" + stateValue + "') failed. " + msg);
                if ~b, continue; end
                testCase.verifyTrue(isstruct(ans_list) && isfield(ans_list, 'jobs'), ...
                    "listActiveBulkUploads(state='" + stateValue + "') response missing 'jobs' field. " + msg);
                if ~isfield(ans_list, 'jobs'), continue; end
                narrative(end+1) = "  Server returned " + numel(ans_list.jobs) + " job(s) for state='" + stateValue + "'.";

                if ismember(stateValue, ["active","all","queued"])
                    jobIds = strings(1, numel(ans_list.jobs));
                    for j = 1:numel(ans_list.jobs)
                        jobIds(j) = string(ans_list.jobs(j).jobId);
                    end
                    narrative(end+1) = "  Testing: state='" + stateValue + "' must include the queued job " + info.jobId + ".";
                    testCase.verifyTrue(ismember(info.jobId, jobIds), ...
                        "Queued job not visible under state='" + stateValue + "'. " + msg);
                end
            end

            testCase.Narrative = narrative;
        end

        function testListActiveBulkUploadsRejectsInvalidStateClientSide(testCase)
            % The wrapper uses mustBeMember to validate the state argument
            % BEFORE making any HTTP request. Passing an invalid state must
            % throw a MATLAB validation error, not silently call the server
            % with bad data.
            testCase.Narrative = "Begin testListActiveBulkUploadsRejectsInvalidStateClientSide";
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling listActiveBulkUploads with state='nonsense'; expecting MATLAB validator to throw before any network call.";
            try
                ndi.cloud.api.files.listActiveBulkUploads(testCase.DatasetID, 'state', 'nonsense');
                threw = false;
            catch
                threw = true;
            end
            msg = ndi.unittest.cloud.APIMessage(narrative, threw, ...
                struct('expected','MATLAB:validators error','actual','no error'), [], 'client-side validation');
            testCase.verifyTrue(threw, ...
                "listActiveBulkUploads accepted an invalid state value without throwing client-side. " + msg);

            testCase.Narrative = narrative;
        end

        function testWaitForBulkUploadDrivesQueuedJobToComplete(testCase)
            % End-to-end happy path: provision a job, PUT a real zip,
            % waitForBulkUpload must drive it to state='complete' before
            % the timeout. The final answer struct must satisfy the same
            % schema as getBulkUploadStatus.
            testCase.Narrative = "Begin testWaitForBulkUploadDrivesQueuedJobToComplete";
            narrative = testCase.Narrative;

            narrative(end+1) = "STEP 1: Provisioning a bulk upload URL.";
            [info, ~] = testCase.createBulkJob(narrative);
            narrative(end+1) = "Job created with jobId=" + info.jobId + ".";

            narrative(end+1) = "STEP 2: Building a small zip with 2 files for extraction.";
            [tempFolder, zipFilePath, ~] = testCase.makeSmallZip(2);
            narrative(end+1) = "Zip archive created at " + zipFilePath + " inside " + tempFolder.Folder + ".";

            narrative(end+1) = "STEP 3: PUTting the zip to the pre-signed URL (no waitForCompletion).";
            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(info.url, zipFilePath, ...
                'jobId', info.jobId);
            narrative(end+1) = "Attempted to call API with URL " + string(url_put);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "PUT of zip archive failed; cannot exercise waitForBulkUpload. " + msg_put);
            if ~b_put, testCase.Narrative = narrative; return; end

            narrative(end+1) = "STEP 4: Calling waitForBulkUpload(jobId, timeout=120, initialInterval=0.5, maxInterval=5).";
            [b_wait, ans_wait, resp_wait, url_wait] = ndi.cloud.api.files.waitForBulkUpload(info.jobId, ...
                'timeout', 120, 'initialInterval', 0.5, 'maxInterval', 5);
            narrative(end+1) = "Attempted to call API with URL " + string(url_wait);
            msg_wait = ndi.unittest.cloud.APIMessage(narrative, b_wait, ans_wait, resp_wait, url_wait);
            testCase.verifyTrue(b_wait, "waitForBulkUpload did not drive the job to 'complete'. " + msg_wait);
            if ~b_wait, testCase.Narrative = narrative; return; end

            narrative(end+1) = "Testing: final answer is a struct with 'state' field.";
            testCase.verifyTrue(isstruct(ans_wait) && isfield(ans_wait, 'state'), ...
                "waitForBulkUpload final answer is not a status struct. " + msg_wait);
            if isstruct(ans_wait) && isfield(ans_wait, 'state')
                narrative(end+1) = "Testing: final state == 'complete'.";
                testCase.verifyEqual(string(ans_wait.state), "complete", ...
                    "waitForBulkUpload returned b=true but final state was '" + string(ans_wait.state) + "'. " + msg_wait);
            end

            narrative(end+1) = "STEP 5: Re-reading status post-completion via getBulkUploadStatus and confirming consistency.";
            [b_chk, ans_chk, resp_chk, url_chk] = ndi.cloud.api.files.getBulkUploadStatus(info.jobId);
            msg_chk = ndi.unittest.cloud.APIMessage(narrative, b_chk, ans_chk, resp_chk, url_chk);
            testCase.verifyTrue(b_chk, "getBulkUploadStatus failed after wait reported complete. " + msg_chk);
            if b_chk && isstruct(ans_chk) && isfield(ans_chk, 'state')
                testCase.verifyEqual(string(ans_chk.state), "complete", ...
                    "getBulkUploadStatus disagrees with waitForBulkUpload on the final state. " + msg_chk);
            end

            testCase.Narrative = narrative;
        end

        function testWaitForBulkUploadTimesOutOnUnknownJob(testCase)
            % Pointing waitForBulkUpload at a non-existent job means every
            % poll returns failure; eventually the wait must hit its
            % timeout and report b=false with a 'timeout' marker, NOT loop
            % forever. Use a deliberately short overall timeout.
            testCase.Narrative = "Begin testWaitForBulkUploadTimesOutOnUnknownJob";
            narrative = testCase.Narrative;

            bogusJobId = "no-such-job-" + string(did.ido.unique_id());
            narrative(end+1) = "Calling waitForBulkUpload on a fabricated jobId with timeout=4, initialInterval=0.5, maxInterval=2.";
            t0 = tic;
            [b, ans_wait, resp, url] = ndi.cloud.api.files.waitForBulkUpload(bogusJobId, ...
                'timeout', 4, 'initialInterval', 0.5, 'maxInterval', 2);
            elapsed = toc(t0);
            narrative(end+1) = "Wait returned after " + elapsed + "s. Last URL polled: " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_wait, resp, url);

            narrative(end+1) = "Testing: waitForBulkUpload returned b=false (no terminal 'complete' state).";
            testCase.verifyFalse(b, "waitForBulkUpload reported success for an unknown jobId. " + msg);

            narrative(end+1) = "Testing: total elapsed time is at least the timeout (4s) and not absurdly long.";
            testCase.verifyGreaterThanOrEqual(elapsed, 3.5, ...
                "waitForBulkUpload returned before its timeout. " + msg);
            testCase.verifyLessThan(elapsed, 30, ...
                "waitForBulkUpload took an unreasonably long time to time out. " + msg);

            testCase.Narrative = narrative;
        end

        function testWaitForAllBulkUploadsOnFreshDatasetReturnsImmediately(testCase)
            % A dataset that has never had a bulk upload has no active jobs
            % and no failed jobs. waitForAllBulkUploads must return b=true
            % almost immediately rather than spending the timeout asleep.
            testCase.Narrative = "Begin testWaitForAllBulkUploadsOnFreshDatasetReturnsImmediately";
            narrative = testCase.Narrative;

            narrative(end+1) = "Calling waitForAllBulkUploads on a brand-new dataset (no uploads yet).";
            t0 = tic;
            [b, ans_wait, resp, url] = ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID, ...
                'timeout', 30, 'initialInterval', 0.5, 'maxInterval', 2);
            elapsed = toc(t0);
            narrative(end+1) = "Wait returned after " + elapsed + "s. Last URL polled: " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_wait, resp, url);

            narrative(end+1) = "Testing: returns b=true (no active jobs, no failed jobs).";
            testCase.verifyTrue(b, "waitForAllBulkUploads did not return success on a fresh dataset. " + msg);

            narrative(end+1) = "Testing: returns quickly (<5s wall clock); fresh dataset must not consume the timeout.";
            testCase.verifyLessThan(elapsed, 5, ...
                "waitForAllBulkUploads spent too long on a fresh dataset. " + msg);

            if isstruct(ans_wait) && isfield(ans_wait, 'state')
                narrative(end+1) = "Testing: final state is 'complete'.";
                testCase.verifyEqual(string(ans_wait.state), "complete", ...
                    "waitForAllBulkUploads on a fresh dataset returned an unexpected state '" + string(ans_wait.state) + "'. " + msg);
            end

            testCase.Narrative = narrative;
        end

        function testWaitForAllBulkUploadsDrivesActiveJobToComplete(testCase)
            % End-to-end happy path: provision a job, PUT a real zip,
            % waitForAllBulkUploads must drive the active set to empty
            % before the timeout and report state='complete'.
            testCase.Narrative = "Begin testWaitForAllBulkUploadsDrivesActiveJobToComplete";
            narrative = testCase.Narrative;

            narrative(end+1) = "STEP 1: Provisioning a bulk upload URL (creates a queued job).";
            [info, ~] = testCase.createBulkJob(narrative);
            narrative(end+1) = "Job created with jobId=" + info.jobId + ".";

            narrative(end+1) = "STEP 2: Building a small zip and PUTting it (no per-call wait).";
            [tempFolder, zipFilePath, ~] = testCase.makeSmallZip(2);
            narrative(end+1) = "Zip archive created at " + zipFilePath + " inside " + tempFolder.Folder + ".";
            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(info.url, zipFilePath, ...
                'jobId', info.jobId);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "PUT of zip archive failed; cannot exercise waitForAllBulkUploads. " + msg_put);
            if ~b_put, testCase.Narrative = narrative; return; end

            narrative(end+1) = "STEP 3: Calling waitForAllBulkUploads with timeout=120, initialInterval=0.5, maxInterval=5.";
            [b, ans_wait, resp, url] = ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID, ...
                'timeout', 120, 'initialInterval', 0.5, 'maxInterval', 5);
            narrative(end+1) = "Last poll URL was " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_wait, resp, url);

            testCase.verifyTrue(b, "waitForAllBulkUploads did not drive the active set to empty. " + msg);
            if ~b, testCase.Narrative = narrative; return; end

            narrative(end+1) = "Testing: final answer struct has state='complete'.";
            testCase.verifyTrue(isstruct(ans_wait) && isfield(ans_wait, 'state'), ...
                "waitForAllBulkUploads final answer is not a struct with 'state'. " + msg);
            if isstruct(ans_wait) && isfield(ans_wait, 'state')
                testCase.verifyEqual(string(ans_wait.state), "complete", ...
                    "waitForAllBulkUploads returned b=true but final state was '" + string(ans_wait.state) + "'. " + msg);
            end

            narrative(end+1) = "STEP 4: Re-asking listActiveBulkUploads(state='active') to confirm the active set is empty.";
            [b_chk, ans_chk, resp_chk, url_chk] = ndi.cloud.api.files.listActiveBulkUploads(testCase.DatasetID);
            msg_chk = ndi.unittest.cloud.APIMessage(narrative, b_chk, ans_chk, resp_chk, url_chk);
            testCase.verifyTrue(b_chk, "Follow-up listActiveBulkUploads call failed. " + msg_chk);
            if b_chk && isstruct(ans_chk) && isfield(ans_chk, 'jobs')
                testCase.verifyEmpty(ans_chk.jobs, ...
                    "Active set was reportedly drained but the follow-up list is non-empty. " + msg_chk);
            end

            testCase.Narrative = narrative;
        end

        function testWaitForAllBulkUploadsTimesOutWhenJobNeverProgresses(testCase)
            % A queued job that never receives a zip stays active forever.
            % Pointing waitForAllBulkUploads at such a dataset must respect
            % the timeout and return b=false within roughly the deadline,
            % NOT loop forever.
            testCase.Narrative = "Begin testWaitForAllBulkUploadsTimesOutWhenJobNeverProgresses";
            narrative = testCase.Narrative;

            narrative(end+1) = "STEP 1: Provisioning a bulk upload URL but deliberately not PUTting any zip.";
            [info, ~] = testCase.createBulkJob(narrative);
            narrative(end+1) = "Job created with jobId=" + info.jobId + " and will remain queued.";

            narrative(end+1) = "STEP 2: Calling waitForAllBulkUploads with timeout=4, initialInterval=0.5, maxInterval=2.";
            t0 = tic;
            [b, ans_wait, resp, url] = ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID, ...
                'timeout', 4, 'initialInterval', 0.5, 'maxInterval', 2);
            elapsed = toc(t0);
            narrative(end+1) = "Wait returned after " + elapsed + "s. Last URL polled: " + string(url);
            msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_wait, resp, url);

            narrative(end+1) = "Testing: waitForAllBulkUploads returned b=false (active set never drained).";
            testCase.verifyFalse(b, "waitForAllBulkUploads reported success while a queued job remains active. " + msg);

            narrative(end+1) = "Testing: total elapsed time is at least the timeout (4s) and not absurdly long.";
            testCase.verifyGreaterThanOrEqual(elapsed, 3.5, ...
                "waitForAllBulkUploads returned before its timeout. " + msg);
            testCase.verifyLessThan(elapsed, 30, ...
                "waitForAllBulkUploads took an unreasonably long time to time out. " + msg);

            if isstruct(ans_wait) && isfield(ans_wait, 'state')
                narrative(end+1) = "Testing: final state is 'timeout'.";
                testCase.verifyEqual(string(ans_wait.state), "timeout", ...
                    "waitForAllBulkUploads timed out but reported state '" + string(ans_wait.state) + "'. " + msg);
            end

            testCase.Narrative = narrative;
        end
    end
end
