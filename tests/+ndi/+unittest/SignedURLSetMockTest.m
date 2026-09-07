classdef SignedURLSetMockTest < matlab.unittest.TestCase
% SIGNEDURLSETMOCKTEST - the signed-url-set sequencing logic, against mocks.
%
% The endpoint is live now -- ndi-cloud-node serves file-series members, and
% SignedURLSetTest and FileSeriesRoundTripTest exercise it under
% tests/+ndi/+unittest/+cloud -- but the interesting behaviours here are ones
% a working server will not produce on demand: a cursor that does not advance,
% a job that never reaches a terminal state, a timeout, a truncated or
% mis-shaped result blob.
%
% So these stay, and are the only coverage of those paths. They run through
% the fetchPage / pollStatus / downloadTo seams against the scripted doubles
% in ndi.test.helper. A live test can show the happy path works; only a mock
% can show what happens when it does not.

    methods
        function page = makePage(~, uidUrlPairs, nextCursor)
            % A page struct shaped like the one signedURLSetPage builds.
            m = containers.Map('KeyType','char','ValueType','any');
            for i = 1:size(uidUrlPairs,1)
                m(uidUrlPairs{i,1}) = uidUrlPairs{i,2};
            end
            page = struct('files', m, 'nextCursor', nextCursor, ...
                'expiresAt', '2026-09-07T00:00:00Z');
        end

        function e = okPage(testCase, uidUrlPairs, nextCursor)
            e = struct('ok', true, 'page', testCase.makePage(uidUrlPairs, nextCursor));
        end
    end

    methods (Test)

        % ---- paging ----------------------------------------------------

        function testStopsWhenTheServerReportsNoNextCursor(testCase)
            pages = { testCase.okPage({'9a','u1'; '0b','u2'}, '') };
            call = ndi.test.helper.ScriptedSignedURLSetAll(pages, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc");

            [b, answer] = call.execute();

            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 1);
            testCase.verifyEqual(answer.pages, 1);
            testCase.verifyEqual(double(answer.files.Count), 2);
            testCase.verifyFalse(isfield(answer,'state'), ...
                'a completed walk carries no failure state');
        end

        function testFollowsTheCursorAcrossPages(testCase)
            pages = { testCase.okPage({'9a','u1'}, 'c1'), ...
                      testCase.okPage({'0b','u2'}, 'c2'), ...
                      testCase.okPage({'cc','u3'}, '') };
            call = ndi.test.helper.ScriptedSignedURLSetAll(pages, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc");

            [b, answer] = call.execute();

            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.pages, 3);
            testCase.verifyEqual(call.cursorsSeen, {'', 'c1', 'c2'}, ...
                'each page must be asked for with the cursor the last one gave');
            testCase.verifyEqual(double(answer.files.Count), 3);
            testCase.verifyEqual(answer.files('cc'), 'u3');
        end

        function testExpiresAtComesFromTheLastPage(testCase)
            p1 = testCase.okPage({'9a','u1'}, 'c1');
            p2 = testCase.okPage({'0b','u2'}, '');
            p2.page.expiresAt = '2026-12-31T00:00:00Z';
            call = ndi.test.helper.ScriptedSignedURLSetAll({p1, p2}, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc");

            [~, answer] = call.execute();
            testCase.verifyEqual(answer.expiresAt, '2026-12-31T00:00:00Z');
        end

        function testMaxPagesStopsEarlyAndSaysSo(testCase)
            pages = { testCase.okPage({'9a','u1'}, 'c1'), ...
                      testCase.okPage({'0b','u2'}, 'c2'), ...
                      testCase.okPage({'cc','u3'}, '') };
            call = ndi.test.helper.ScriptedSignedURLSetAll(pages, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc", 'maxPages', 2);

            [b, answer] = call.execute();

            % Running off maxPages is a bounded failure, not a success: the
            % caller is holding a partial map and must be able to tell.
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'maxPagesReached');
            testCase.verifyEqual(answer.pages, 2);
            testCase.verifyEqual(double(answer.files.Count), 2);
        end

        function testAFailedPageStopsTheWalk(testCase)
            pages = { testCase.okPage({'9a','u1'}, 'c1'), ...
                      struct('ok', false, 'page', struct('error','boom')) };
            call = ndi.test.helper.ScriptedSignedURLSetAll(pages, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc");

            [b, answer] = call.execute();

            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.error, 'boom', ...
                'the failing page''s body is what the caller needs to see');
            testCase.verifyEqual(call.callCount, 2, 'and the walk stops there');
        end

        function testACursorThatDoesNotAdvanceIsRefused(testCase)
            % A server that hands back the cursor just used would page for
            % ever. This is the one case where looping is the failure.
            pages = { testCase.okPage({'9a','u1'}, 'c1'), ...
                      testCase.okPage({'0b','u2'}, 'c1') };
            call = ndi.test.helper.ScriptedSignedURLSetAll(pages, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc");

            testCase.verifyError(@() call.execute(), ...
                'NDI:CloudApi:SignedURLSet:CursorDidNotAdvance');
        end

        function testLaterPagesDoNotLoseEarlierUids(testCase)
            pages = { testCase.okPage({'9a','u1'; '0b','u2'}, 'c1'), ...
                      testCase.okPage({'cc','u3'}, '') };
            call = ndi.test.helper.ScriptedSignedURLSetAll(pages, ...
                'cloudDatasetID', "d", 'cloudDocumentID', "doc");

            [~, answer] = call.execute();
            testCase.verifyEqual(sort(keys(answer.files)), {'0b','9a','cc'});
            testCase.verifyEqual(answer.pageCount, 3, ...
                'pageCount counts entries seen, not pages walked');
        end

        % ---- job polling -----------------------------------------------

        function testJobReadyIsSuccess(testCase)
            states = { struct('ok', true, 'status', ...
                struct('state','ready','resultUrl','https://s3/blob')) };
            call = ndi.test.helper.ScriptedSignedURLSetJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.resultUrl, 'https://s3/blob');
            testCase.verifyEqual(call.callCount, 1);
        end

        function testJobFailedIsTerminalNotRetried(testCase)
            states = { struct('ok', true, 'status', struct('state','failed')) };
            call = ndi.test.helper.ScriptedSignedURLSetJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, ~] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(call.callCount, 1, ...
                'a failed job must not be polled again');
        end

        function testJobIsPolledUntilItIsReady(testCase)
            states = { struct('ok', true, 'status', struct('state','queued')), ...
                       struct('ok', true, 'status', struct('state','running')), ...
                       struct('ok', true, 'status', struct('state','ready')) };
            call = ndi.test.helper.ScriptedSignedURLSetJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 3);
            testCase.verifyEqual(answer.state, 'ready');
        end

        function testJobThatNeverFinishesTimesOut(testCase)
            states = { struct('ok', true, 'status', struct('state','running')) };
            call = ndi.test.helper.ScriptedSignedURLSetJob(states, 'jobId', "j1", ...
                'timeout', 0.05, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyTrue(isfield(answer,'elapsed'));
        end

        function testAnApiErrorIsNotMistakenForATerminalState(testCase)
            % A failed poll is not a failed job; keep polling until the
            % deadline rather than reporting the job dead.
            states = { struct('ok', false, 'status', struct('message','gateway')) };
            % A generous deadline against a 10 ms interval: the assertion below
            % is that more than one poll happened, and a tight timeout would
            % make that a race against a loaded runner rather than a test.
            call = ndi.test.helper.ScriptedSignedURLSetJob(states, 'jobId', "j1", ...
                'timeout', 0.5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyGreaterThan(call.callCount, 1, ...
                'a transient API error should be retried, not treated as terminal');
        end

        % ---- result blob -----------------------------------------------

        function testPlainResultBlobIsParsed(testCase)
            uid = '4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6';
            call = ndi.test.helper.ScriptedSignedURLSetResult('resultUrl', "https://s3/blob");
            call.blobText = ['{"fileCount":1,"generatedAt":"t0","files":{"' uid '":"https://s3/x"}}'];

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.files(uid), 'https://s3/x');
            testCase.verifyEqual(answer.fileCount, 1);
            testCase.verifyEqual(answer.generatedAt, 't0');
        end

        function testGzippedResultBlobIsParsed(testCase)
            % What the endpoint actually serves.
            uid = '9a11111111111111_1111111111111111';
            call = ndi.test.helper.ScriptedSignedURLSetResult('resultUrl', "https://s3/blob");
            call.blobText = ['{"fileCount":1,"files":{"' uid '":"https://s3/y"}}'];
            call.gzipped = true;

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.files(uid), 'https://s3/y');
        end

        function testAFailedDownloadReportsRatherThanThrows(testCase)
            call = ndi.test.helper.ScriptedSignedURLSetResult('resultUrl', "https://s3/blob");
            call.downloadFails = true;

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyTrue(isfield(answer,'error'));
        end

        % ---- page assembly ----------------------------------------------

        function testPageCarriesCursorAndExpiry(testCase)
            txt = ['{"files":{"9a":"u1"},"nextCursor":"c1",' ...
                   '"expiresAt":"2026-09-07T00:00:00Z"}'];
            page = ndi.cloud.api.implementation.files.signedURLSetPage(...
                jsondecode(txt), txt);

            testCase.verifyEqual(page.nextCursor, 'c1');
            testCase.verifyEqual(page.expiresAt, '2026-09-07T00:00:00Z');
            testCase.verifyEqual(page.files('9a'), 'u1');
        end

        function testPagePreservesEveryFieldTheServerSent(testCase)
            % The live cloud test checks page.totalCount against the size of
            % the map. An earlier version of signedURLSetPage built a fresh
            % struct from a hand-picked set of fields and dropped the rest,
            % which broke that silently -- and would drop whatever the
            % endpoint grows next. Only `files` is replaced.
            txt = ['{"datasetId":"d1","documentId":"doc1","totalCount":3,' ...
                   '"limit":500,"files":{"9a":"u1"},"nextCursor":null,' ...
                   '"expiresAt":"2026-09-07T00:00:00Z"}'];
            page = ndi.cloud.api.implementation.files.signedURLSetPage(...
                jsondecode(txt), txt);

            testCase.verifyEqual(page.totalCount, 3);
            testCase.verifyEqual(page.datasetId, 'd1');
            testCase.verifyEqual(page.documentId, 'doc1');
            testCase.verifyEqual(page.limit, 500);
            testCase.verifyTrue(isa(page.files,'containers.Map'), ...
                'files is the one field that is replaced');
            testCase.verifyEqual(page.files('9a'), 'u1');
        end

        function testLastPageHasAnEmptyCursor(testCase)
            txt = '{"files":{"9a":"u1"},"nextCursor":null}';
            page = ndi.cloud.api.implementation.files.signedURLSetPage(...
                jsondecode(txt), txt);
            testCase.verifyEmpty(page.nextCursor, ...
                'a null cursor is what ends the walk in getSignedURLSetAll');
        end
    end
end
