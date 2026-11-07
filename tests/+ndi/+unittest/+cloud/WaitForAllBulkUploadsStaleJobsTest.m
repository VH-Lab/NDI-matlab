classdef WaitForAllBulkUploadsStaleJobsTest < matlab.unittest.TestCase
    % WAITFORALLBULKUPLOADSSTALEJOBSTEST - offline tests for the job
    % filtering in ndi.cloud.api.implementation.files.WaitForAllBulkUploads.
    %
    % The server creates a 'queued' BulkUploadJob as soon as a client asks
    % for a bulk upload URL. If the zip upload then fails or never happens,
    % the job stays 'queued', and waitForAllBulkUploads used to spend its
    % full 300 s timeout on every call for that dataset. Separately,
    % state='failed' returned every failure the dataset ever had, so
    % requireAllComplete reported failure forever after one bad upload.
    % These tests exercise the helpers that set abandoned 'queued' jobs
    % aside and keep only recent failures. They build job structs locally,
    % so they need no network or credentials.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testParseTimestampFormats(testCase)
            expected = datetime(2026, 11, 5, 12, 34, 56, 'TimeZone', 'UTC');
            inputs = ["2026-11-05T12:34:56.789Z", "2026-11-05T12:34:56Z", ...
                "2026-11-05T12:34:56.123456Z", "2026-11-05T12:34:56+00:00", ...
                "2026-11-05T13:34:56+01:00", "2026-11-05T12:34:56"];
            for k = 1:numel(inputs)
                t = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.parseTimestamp(inputs(k));
                testCase.verifyFalse(isnat(t), "Could not parse " + inputs(k));
                testCase.verifyLessThan(abs(seconds(t - expected)), 1, ...
                    "Wrong time parsed from " + inputs(k));
            end
            % char input works too
            t = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.parseTimestamp('2026-11-05T12:34:56Z');
            testCase.verifyLessThan(abs(seconds(t - expected)), 1);
        end

        function testParseTimestampBadInputIsNaT(testCase)
            bad = {[], '', "", 'not a date', 42};
            for k = 1:numel(bad)
                t = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.parseTimestamp(bad{k});
                testCase.verifyTrue(isnat(t));
            end
        end

        function testOldQueuedJobIsStale(testCase)
            nowUtc = datetime(2026, 11, 5, 12, 0, 0, 'TimeZone', 'UTC');
            jobs = [ ...
                ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("old", "queued", "2026-11-04T12:00:00.000Z"), ...
                ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("new", "queued", "2026-11-05T11:55:00.000Z")];
            [live, stale] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.partitionStaleJobs(jobs, 3600, nowUtc);
            testCase.verifyTrue(isstruct(live));
            testCase.verifyEqual(numel(live), 1);
            testCase.verifyEqual(string(live(1).jobId), "new");
            testCase.verifyEqual(numel(stale), 1);
            testCase.verifyEqual(string(stale(1).jobId), "old");
        end

        function testExtractingJobIsNeverStale(testCase)
            % A big extraction can run for hours; only the server can tell
            % slow from dead, so the client always waits for it.
            nowUtc = datetime(2026, 11, 5, 12, 0, 0, 'TimeZone', 'UTC');
            jobs = ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job( ...
                "x", "extracting", "2026-11-04T09:00:00Z");
            jobs.startedAt = '2026-11-04T09:01:00Z';
            [live, stale] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.partitionStaleJobs(jobs, 3600, nowUtc);
            testCase.verifyEqual(numel(live), 1);
            testCase.verifyEmpty(stale);
        end

        function testUnparseableTimestampIsKeptLive(testCase)
            nowUtc = datetime(2026, 11, 5, 12, 0, 0, 'TimeZone', 'UTC');
            jobs = ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("q", "queued", "garbage");
            [live, stale] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.partitionStaleJobs(jobs, 3600, nowUtc);
            testCase.verifyEqual(numel(live), 1);
            testCase.verifyEmpty(stale);
        end

        function testCellArrayOfJobs(testCase)
            % jsondecode returns a cell array when job structs differ in fields.
            nowUtc = datetime(2026, 11, 5, 12, 0, 0, 'TimeZone', 'UTC');
            jobs = {struct('jobId', 'a', 'state', 'queued', 'createdAt', '2026-11-01T00:00:00Z'), ...
                    struct('jobId', 'b', 'state', 'queued', 'createdAt', '2026-11-05T11:59:00Z', 'error', '')};
            [live, stale] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.partitionStaleJobs(jobs, 3600, nowUtc);
            testCase.verifyTrue(iscell(live));
            testCase.verifyEqual(numel(live), 1);
            testCase.verifyEqual(live{1}.jobId, 'b');
            testCase.verifyEqual(numel(stale), 1);
            testCase.verifyEqual(stale{1}.jobId, 'a');
        end

        function testEmptyJobs(testCase)
            nowUtc = datetime('now', 'TimeZone', 'UTC');
            [live, stale] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.partitionStaleJobs([], 3600, nowUtc);
            testCase.verifyEmpty(live);
            testCase.verifyEmpty(stale);
            recent = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobsCompletedSince([], nowUtc);
            testCase.verifyEmpty(recent);
        end

        function testOnlyRecentFailuresCount(testCase)
            since = datetime(2026, 11, 5, 11, 0, 0, 'TimeZone', 'UTC');
            old = ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("old", "failed", "2026-10-01T00:00:00Z");
            old.completedAt = '2026-10-01T00:05:00Z';
            recentJob = ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("recent", "failed", "2026-11-05T09:00:00Z");
            % Created before the cutoff but failed after it: counts.
            recentJob.completedAt = '2026-11-05T11:30:00Z';
            recent = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobsCompletedSince([old, recentJob], since);
            testCase.verifyEqual(numel(recent), 1);
            testCase.verifyEqual(string(recent(1).jobId), "recent");
        end

        function testFailureWithoutCompletedAtFallsBackToCreatedAt(testCase)
            since = datetime(2026, 11, 5, 11, 0, 0, 'TimeZone', 'UTC');
            old = ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("old", "failed", "2026-10-01T00:00:00Z");
            recent = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobsCompletedSince(old, since);
            testCase.verifyEmpty(recent);
        end

        function testFailureWithNoUsableTimeIsKept(testCase)
            % Err toward reporting a failure when the server response is odd.
            since = datetime(2026, 11, 5, 11, 0, 0, 'TimeZone', 'UTC');
            odd = ndi.unittest.cloud.WaitForAllBulkUploadsStaleJobsTest.job("odd", "failed", "garbage");
            recent = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobsCompletedSince(odd, since);
            testCase.verifyEqual(numel(recent), 1);
        end

    end

    methods (Static)
        function s = job(jobId, state, createdAt)
            s = struct('jobId', char(jobId), 'state', char(state), ...
                'createdAt', char(createdAt), 'startedAt', [], 'completedAt', []);
        end
    end
end
