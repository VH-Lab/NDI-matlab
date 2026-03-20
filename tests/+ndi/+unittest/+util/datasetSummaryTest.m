classdef datasetSummaryTest < matlab.unittest.TestCase

    methods (Test)

        function testCompareIdenticalSummaries(testCase)
            % Two identical dataset summaries should produce an empty report
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyEmpty(report, 'Report should be empty for identical summaries.');
        end

        function testCompareNumSessionsMismatch(testCase)
            % Summaries with different numSessions should report a difference
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            s2.numSessions = 5;
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyNotEmpty(report, 'Report should flag numSessions mismatch.');
            testCase.verifyTrue(contains(report{1}, 'numSessions'), ...
                'Report should mention numSessions.');
        end

        function testCompareReferencesMismatch(testCase)
            % Summaries with different references should be flagged
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            s2.references = {'different_ref'};
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyNotEmpty(report, 'Report should flag references mismatch.');
            reportStr = strjoin(report, ' ');
            testCase.verifyTrue(contains(reportStr, 'references'), ...
                'Report should mention references.');
        end

        function testCompareSessionIdsMismatch(testCase)
            % Summaries with different session IDs should be flagged
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            s2.sessionIds = {'different_id'};
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyNotEmpty(report, 'Report should flag sessionIds mismatch.');
            reportStr = strjoin(report, ' ');
            testCase.verifyTrue(contains(reportStr, 'Session IDs'), ...
                'Report should mention Session IDs.');
        end

        function testCompareSessionSummaryDifferences(testCase)
            % Differences in per-session summaries should be reported
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            % Alter a field in the session summary
            s2.sessionSummaries{1}.reference = 'changed_ref';
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyNotEmpty(report, 'Report should flag session summary differences.');
            reportStr = strjoin(report, ' ');
            testCase.verifyTrue(contains(reportStr, 'Session sess_001'), ...
                'Report should identify the session with the difference.');
        end

        function testCompareWithExcludeFiles(testCase)
            % excludeFiles should be passed through to session comparison
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            % Add a file to s2's session summary that is excluded
            s2.sessionSummaries{1}.files = [s1.sessionSummaries{1}.files, {'datasetSummary.json'}];
            report = ndi.util.compareDatasetSummary(s1, s2, ...
                'excludeFiles', {'datasetSummary.json'});
            testCase.verifyEmpty(report, ...
                'Excluded files should not cause a difference.');
        end

        function testCompareDocumentCountsMismatch(testCase)
            % Document count differences should be reported
            s1 = makeDatasetSummaryWithDocCounts();
            s2 = s1;
            s2.documentCounts{1}.count = 999;
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyNotEmpty(report, 'Report should flag document count mismatch.');
            reportStr = strjoin(report, ' ');
            testCase.verifyTrue(contains(reportStr, 'Document count'), ...
                'Report should mention document count.');
        end

        function testCompareDocumentCountsMatch(testCase)
            % Matching document counts should produce no extra reports
            s1 = makeDatasetSummaryWithDocCounts();
            s2 = s1;
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyEmpty(report, ...
                'Identical summaries with doc counts should produce empty report.');
        end

        function testCompareHandlesJsondecodeSingleElement(testCase)
            % jsondecode may return char instead of cell for single-element arrays
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            % Simulate jsondecode converting single-element cell to char
            s2.references = 'ref1';
            s2.sessionIds = 'sess_001';
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyEmpty(report, ...
                'Should handle jsondecode single-element conversion gracefully.');
        end

        function testCompareHandlesStructArraySessionSummaries(testCase)
            % jsondecode may return struct array instead of cell array
            s1 = makeMinimalDatasetSummary();
            s2 = s1;
            % Convert cell to struct array (simulating jsondecode behavior)
            s2.sessionSummaries = s1.sessionSummaries{1}; % struct, not cell
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyEmpty(report, ...
                'Should handle struct array session summaries from jsondecode.');
        end

        function testCompareMultipleSessions(testCase)
            % Test with multiple sessions to verify matching by sessionId
            s1 = makeMultiSessionDatasetSummary();
            s2 = s1;
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyEmpty(report, ...
                'Identical multi-session summaries should produce empty report.');
        end

        function testCompareMultiSessionsOneDiffers(testCase)
            % With multiple sessions, only the differing one should be reported
            s1 = makeMultiSessionDatasetSummary();
            s2 = s1;
            s2.sessionSummaries{2}.reference = 'altered_ref';
            report = ndi.util.compareDatasetSummary(s1, s2);
            testCase.verifyNotEmpty(report, 'Should detect difference in second session.');
            reportStr = strjoin(report, ' ');
            testCase.verifyTrue(contains(reportStr, 'sess_002'), ...
                'Report should identify the second session.');
            testCase.verifyFalse(contains(reportStr, 'sess_001'), ...
                'Report should not flag the unchanged first session.');
        end

    end
end

function s = makeMinimalDatasetSummary()
% Create a minimal dataset summary for testing
    sess1 = struct();
    sess1.reference = 'ref1';
    sess1.sessionId = 'sess_001';
    sess1.files = {'file1.txt', 'file2.txt'};
    sess1.filesInDotNDI = {'db.sqlite'};
    sess1.daqSystemNames = {'daq1'};
    sess1.daqSystemDetails = struct('filenavigator_class', 'ndi.file.navigator', ...
        'daqreader_class', 'ndi.daq.reader', ...
        'epochNodes_filenavigator', [], ...
        'epochNodes_daqsystem', []);
    sess1.probes = struct('name', 'probe1', 'reference', 1, ...
        'type', 'n-trode', 'subject_id', 'sub1');

    s = struct();
    s.numSessions = 1;
    s.references = {'ref1'};
    s.sessionIds = {'sess_001'};
    s.sessionSummaries = {sess1};
end

function s = makeDatasetSummaryWithDocCounts()
% Create a dataset summary that includes documentCounts
    s = makeMinimalDatasetSummary();
    s.documentCounts = {struct('sessionId', 'sess_001', 'count', 10)};
end

function s = makeMultiSessionDatasetSummary()
% Create a dataset summary with two sessions
    sess1 = struct();
    sess1.reference = 'ref1';
    sess1.sessionId = 'sess_001';
    sess1.files = {'file1.txt'};
    sess1.filesInDotNDI = {};
    sess1.daqSystemNames = {};
    sess1.daqSystemDetails = struct('filenavigator_class', {}, 'daqreader_class', {}, ...
        'epochNodes_filenavigator', {}, 'epochNodes_daqsystem', {});
    sess1.probes = struct('name', {}, 'reference', {}, 'type', {}, 'subject_id', {});

    sess2 = struct();
    sess2.reference = 'ref2';
    sess2.sessionId = 'sess_002';
    sess2.files = {'data.bin'};
    sess2.filesInDotNDI = {};
    sess2.daqSystemNames = {};
    sess2.daqSystemDetails = struct('filenavigator_class', {}, 'daqreader_class', {}, ...
        'epochNodes_filenavigator', {}, 'epochNodes_daqsystem', {});
    sess2.probes = struct('name', {}, 'reference', {}, 'type', {}, 'subject_id', {});

    s = struct();
    s.numSessions = 2;
    s.references = {'ref1', 'ref2'};
    s.sessionIds = {'sess_001', 'sess_002'};
    s.sessionSummaries = {sess1, sess2};
end
