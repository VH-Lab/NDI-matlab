classdef TestBuildProfile < matlab.unittest.TestCase
    % TestBuildProfile - ndi.fun.doc.lightsheet.BuildProfile, on made-up timings.
    %
    % The summary's shares and rates, and the CSV it appends. (A real
    % build's profile is checked by ndi.unittest.job.TestLightsheetToCloudJob.)
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testTheSummarySaysWhereTheTimeWent(testCase)
            % 10 s per batch: 4 waiting to read, 1 assembling, 3 compressing
            % on 4 workers that were busy 6 of their 12 s, 1.5 uploading
            % (0.5 URLs, 1 waiting for curl), 0.5 progress.
            r = testCase.row(struct('readWait', 4, 'assemble', 1, 'compress', 3, ...
                'workers', 4, 'workerBusy', 6, 'upload', 1.5, 'urls', 0.5, 'send', 1, ...
                'progress', 0.5, 'total', 10, 'mbChunks', 100, 'mbOut', 40, 'mbRead', 300));
            t = ndi.fun.doc.lightsheet.BuildProfile.summarize([r r]);
            testCase.verifySubstring(t, '2 batches');
            testCase.verifySubstring(t, 'read-wait 40%');
            testCase.verifySubstring(t, 'assemble 10%');
            testCase.verifySubstring(t, 'compress 30% (workers 50% busy)');
            testCase.verifySubstring(t, 'upload 15% (URLs 5%, staging+CRC 0%, waiting for curl 10%');
            testCase.verifySubstring(t, 'progress 5%, other 0%');
            testCase.verifySubstring(t, '10.0 MB/s of chunks made, 4.0 MB/s compressed, 30.0 MB/s read');
        end

        function testNothingToSay(testCase)
            testCase.verifyEqual(ndi.fun.doc.lightsheet.BuildProfile.summarize( ...
                ndi.fun.doc.lightsheet.BuildProfile.emptyRows()), 'no batches');
        end

        function testEachBatchIsARowOfTheLog(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            log = fullfile(folder, 'profile.csv');
            p = ndi.fun.doc.lightsheet.BuildProfile(log, 3600);
            p.add(testCase.row(struct('level', 'Level 0 (mean)', 'total', 2)));
            p.add(testCase.row(struct('level', 'Level 0 (mean)', 'total', 3)));
            % A resumed build appends, with no second header.
            q = ndi.fun.doc.lightsheet.BuildProfile(log, 3600);
            q.add(testCase.row(struct('level', 'Level 1 (max)', 'total', 4)));
            lines = splitlines(strtrim(fileread(log)));
            testCase.verifyNumElements(lines, 4);
            testCase.verifyTrue(startsWith(lines{1}, 'when,level,superblock'));
            testCase.verifySubstring(lines{4}, '"Level 1 (max)"');
            T = readtable(log);
            testCase.verifyEqual(T.total(:).', [2 3 4]);
            testCase.verifyNumElements(p.rows, 2);
        end

        function testALevelEndsWithASummary(testCase)
            p = ndi.fun.doc.lightsheet.BuildProfile('', 3600);
            p.add(testCase.row(struct('total', 1)));
            out = evalc('p.endLevel(''Level 0 (mean)'')');
            testCase.verifySubstring(out, '[profile] Level 0 (mean), whole level: 1 batches');
            out = evalc('p.endLevel(''Level 1 (mean)'')');
            testCase.verifyEmpty(strtrim(out), 'a level with no batches says nothing');
        end
    end

    methods
        function r = row(~, given)
        % A BuildProfile row: zeros, overridden by GIVEN.
            r = struct('level', 'Level 0 (mean)', 'superblock', 1, ...
                'nSuperBlocks', 1, 'chunks', 16, 'workers', 1, ...
                'mbRead', 0, 'mbChunks', 0, 'mbOut', 0, 'readWait', 0, ...
                'assemble', 0, 'compress', 0, 'workerBusy', 0, 'upload', 0, ...
                'urls', 0, 'stage', 0, 'send', 0, 'verify', 0, ...
                'progress', 0, 'total', 0);
            for f = fieldnames(given).'
                r.(f{1}) = given.(f{1});
            end
        end
    end
end
