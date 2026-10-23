classdef FileUploadWaitMockTest < matlab.unittest.TestCase
% FILEUPLOADWAITMOCKTEST - waitForFileUpload's polling logic, against mocks.
%
% A live server marks a fresh upload processed within a few seconds, so it
% cannot show what happens when it does not: a file that is still pending,
% a uid with no record yet, a transient lookup error, or one of several
% uids lagging the others. The live happy path is in
% tests/+ndi/+unittest/+cloud/FilesTest.m.
%
% Runs entirely through the pollStatus seam against ndi.test.helper.
% ScriptedFileUpload.
%
% Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testAlreadyUploadedReturnsAfterOnePoll(testCase)
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { lookupResult({row("u1", true)}) };
            call = scriptedCall(results, "u1", 5);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.state, 'complete');
            testCase.verifyEmpty(answer.pending);
            testCase.verifyEqual(numel(answer.files), 1);
            testCase.verifyEqual(answer.files(1).uid, 'u1');
            testCase.verifyEqual(call.callCount, 1);
        end

        function testPendingFileIsPolledUntilUploaded(testCase)
            % The case that broke FilesTest: the PUT has returned but the
            % server has not processed it yet (uploaded=false, size=0).
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { lookupResult({row("u1", false)}), ...
                        lookupResult({row("u1", false)}), ...
                        lookupResult({row("u1", true)}) };
            call = scriptedCall(results, "u1", 5);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.state, 'complete');
            testCase.verifyEqual(call.callCount, 3);
            testCase.verifyEqual(numel(answer.files), 1, ...
                'a uid seen pending and then uploaded must be reported once');
            testCase.verifyTrue(answer.files(1).uploaded);
        end

        function testMissingRecordIsTreatedAsPending(testCase)
            % No record at all yet is not a failure: keep waiting.
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { lookupResult({}, "u1"), ...
                        lookupResult({row("u1", true)}) };
            call = scriptedCall(results, "u1", 5);

            [b, ~] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 2);
        end

        function testNeverUploadedTimesOut(testCase)
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { lookupResult({row("u1", false)}) };
            call = scriptedCall(results, "u1", 0.05);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyEqual(answer.pending, "u1");
            testCase.verifyTrue(isfield(answer, 'elapsed'));
            testCase.verifyEqual(numel(answer.files), 1, ...
                'a timeout should report the last row seen for the pending uid');
            testCase.verifyFalse(answer.files(1).uploaded);
        end

        function testAnApiErrorIsRetriedNotTerminal(testCase)
            % A failed lookup is not a failed upload; keep polling.
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { struct('ok', false, 'result', struct('message', 'gateway')), ...
                        lookupResult({row("u1", true)}) };
            call = scriptedCall(results, "u1", 5);

            [b, ~] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 2);
        end

        function testOnlyPendingUidsArePolledAgain(testCase)
            % With several uids, the ones already uploaded drop out of the
            % next lookup, and the result keeps every uploaded row.
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { lookupResult({row("u1", true), row("u2", false)}), ...
                        lookupResult({row("u2", true)}) };
            call = scriptedCall(results, ["u1" "u2"], 5);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 2);
            testCase.verifyEqual(call.polledUids{1}, ["u1" "u2"]);
            testCase.verifyEqual(call.polledUids{2}, "u2");
            testCase.verifyEqual(sort(string({answer.files.uid})), ["u1" "u2"]);
        end

        function testDuplicateUidsArePolledOnce(testCase)
            row = @ndi.test.helper.ScriptedFileUpload.fileRow;
            results = { lookupResult({row("u1", true)}) };
            call = scriptedCall(results, ["u1" "u1"], 5);

            [b, ~] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.polledUids{1}, "u1");
        end
    end
end

% The class lives in package ndi.unittest, so helpers are local functions
% rather than static methods (a bare FileUploadWaitMockTest.x does not
% resolve inside the package).

function r = lookupResult(rows, missing)
    % A scripted lookupFiles answer. ROWS is a cell array of fileRow structs.
    arguments
        rows cell
        missing = strings(1, 0)
    end
    if isempty(rows)
        files = struct('uid', {}, 'uploaded', {}, 'size', {}, 'crc32', {});
        files = files(:);
    else
        files = vertcat(rows{:});
    end
    r = struct('ok', true, 'result', struct('files', files, 'missing', missing));
end

function call = scriptedCall(results, uids, timeout)
    arguments
        results cell
        uids {mustBeText}
        timeout (1,1) {mustBeNumeric}
    end
    call = ndi.test.helper.ScriptedFileUpload(results, ...
        'cloudDatasetID', "ds1", 'cloudFileUIDs', uids, ...
        'timeout', timeout, 'initialInterval', 0.01, 'maxInterval', 0.01);
end
