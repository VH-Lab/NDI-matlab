classdef ConfirmFilesRecordedTest < matlab.unittest.TestCase
    % CONFIRMFILESRECORDEDTEST - tests for ndi.cloud.upload.internal.confirmFilesRecorded
    %
    % A batch (zip) upload's success only means S3 has the zip; the server
    % records the files in a later step that can fail without the client
    % hearing of it (a dataset lost 327 files this way, ndi-cloud-node#175).
    % confirmFilesRecorded waits for the records, uploads again what is
    % never recorded, and reports what is still missing.
    %
    % Needs no cloud access: ndi.test.helper.FakeRecordingServer stands in
    % for the server.

    properties (Constant)
        Uids = ["a" "b" "c"]
        Paths = {'/p/a', '/p/b', '/p/c'}
    end

    methods (Test)

        function testEverythingRecordedNeedsOneLook(testCase)
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {testCase.Uids};
            [ok, report] = testCase.confirm(S);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(S.waitCalls, 1);
            testCase.verifyEmpty(S.resent);
            testCase.verifyEmpty(report.pending);
            testCase.verifyEmpty(report.message);
        end

        function testWaitingGoesOnWhileRecordsArrive(testCase)
            % A slow server that keeps recording is waited for, not
            % duplicated: nothing is sent again.
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {"a", "b", "c"};
            [ok, ~] = testCase.confirm(S);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(S.waitCalls, 3);
            testCase.verifyEmpty(S.resent);
        end

        function testAFileTheServerDroppedIsSentAgain(testCase)
            % The server records a and b, then nothing more (a dropped
            % batch): c is uploaded again and then recorded.
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {"a", "b"};
            [ok, report] = testCase.confirm(S, 'StallTimeout', 7, 'ResendTimeout', 3);
            testCase.verifyTrue(ok);
            testCase.verifyEqual(S.resent, "c");
            testCase.verifyEqual(report.resent, "c");
            testCase.verifyEmpty(report.pending);
            testCase.verifyEqual(S.waitTimeouts, [7 7 7 3], ...
                'StallTimeout while the batch is being recorded, ResendTimeout after resending');
        end

        function testAFileNeverRecordedIsAFailure(testCase)
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {"a"};
            S.NeverRecord = "c";
            [ok, report] = testCase.confirm(S);
            testCase.verifyFalse(ok);
            testCase.verifyEqual(sort(S.resent), ["b" "c"]);
            testCase.verifyEqual(report.pending, "c");
            testCase.verifySubstring(report.message, '1 of 3');
            testCase.verifySubstring(report.message, 'onlyMissing');
        end

        function testAResendThatFailsIsReported(testCase)
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {"a"};
            S.RefuseResend = "b";
            [ok, report] = testCase.confirm(S);
            testCase.verifyFalse(ok);
            testCase.verifyEqual(report.pending, "b");
            testCase.verifyEqual(S.resent, "c");
            testCase.verifyNumElements(report.resendErrors, 1);
            testCase.verifySubstring(report.message, 'refused by the fake');
        end

        function testAResendThatThrowsIsReportedNotRaised(testCase)
            % e.g. the local copy was deleted after the batch went up.
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {["a" "b"]};
            S.ThrowOnResend = "c";
            [ok, report] = testCase.confirm(S);
            testCase.verifyFalse(ok);
            testCase.verifyEqual(report.pending, "c");
            testCase.verifySubstring(report.resendErrors{1}, '/p/c');
        end

        function testDuplicateUidsAreCheckedOnce(testCase)
            S = ndi.test.helper.FakeRecordingServer();
            S.Schedule = {"a"};
            [ok, ~] = ndi.cloud.upload.internal.confirmFilesRecorded("d", ...
                ["a" "b" "b"], {'/p/a', '/p/b', '/p/b'}, 'Verbose', false, ...
                'WaitFcn', @(ids, t) S.wait(ids, t), ...
                'ResendFcn', @(id, p) S.resend(id, p));
            testCase.verifyTrue(ok);
            testCase.verifyEqual(S.resent, "b");
        end

        function testNoUidsIsNothingToDo(testCase)
            S = ndi.test.helper.FakeRecordingServer();
            [ok, ~] = ndi.cloud.upload.internal.confirmFilesRecorded("d", ...
                strings(1, 0), {}, 'Verbose', false, ...
                'WaitFcn', @(ids, t) S.wait(ids, t), ...
                'ResendFcn', @(id, p) S.resend(id, p));
            testCase.verifyTrue(ok);
            testCase.verifyEqual(S.waitCalls, 0);
        end

        function testPathsMustMatchUids(testCase)
            testCase.verifyError(@() ndi.cloud.upload.internal.confirmFilesRecorded( ...
                "d", ["a" "b"], {'/p/a'}, 'Verbose', false), ...
                'NDI:cloud:confirmFilesRecorded:sizeMismatch');
        end
    end

    methods (Access = private)
        function [ok, report] = confirm(testCase, S, varargin)
            [ok, report] = ndi.cloud.upload.internal.confirmFilesRecorded("d", ...
                testCase.Uids, testCase.Paths, 'Verbose', false, ...
                'WaitFcn', @(ids, t) S.wait(ids, t), ...
                'ResendFcn', @(id, p) S.resend(id, p), varargin{:});
        end
    end
end
