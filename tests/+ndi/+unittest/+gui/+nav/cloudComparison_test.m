classdef cloudComparison_test < matlab.unittest.TestCase
    % CLOUDCOMPARISON_TEST - Tests for ndi.gui.nav.cloudComparison helpers.
    %
    % The static helpers run headless; they need no dataset or network.

    methods (Test)
        function testSummaryCountsAndInSync(testCase)
            r = struct('remote_only_ids', ["a" "b"], 'local_only_ids', "c", ...
                'common_ids', ["d" "e" "f"]);
            msg = ndi.gui.nav.cloudComparison.summaryText(r);
            testCase.verifySubstring(msg, 'Only in cloud: 2');
            testCase.verifySubstring(msg, 'Only local: 1');
            testCase.verifySubstring(msg, 'In both: 3');
            testCase.verifyFalse(contains(msg, 'in sync'));
            testCase.verifyFalse(contains(msg, 'Content differs'));

            synced = struct('remote_only_ids', string.empty, ...
                'local_only_ids', string.empty, 'common_ids', "d");
            testCase.verifySubstring(ndi.gui.nav.cloudComparison.summaryText(synced), 'in sync');
        end

        function testSummaryReportsContentDifferences(testCase)
            r = struct('remote_only_ids', string.empty, 'local_only_ids', string.empty, ...
                'common_ids', ["d" "e"], 'mismatched_ids', "e");
            msg = ndi.gui.nav.cloudComparison.summaryText(r);
            testCase.verifySubstring(msg, 'Content differs: 1');
            testCase.verifyFalse(contains(msg, 'in sync'));
        end

        function testComparisonRowsOrderAndLabels(testCase)
            r = struct('remote_only_ids', "r1", 'local_only_ids', "l1", ...
                'common_ids', ["c1" "c2"], 'mismatched_ids', "c2");
            rows = ndi.gui.nav.cloudComparison.comparisonRows(r);
            testCase.verifyEqual(rows(:,1)', {'r1', 'l1', 'c2', 'c1'});
            testCase.verifyEqual(rows(:,2)', {'Only in cloud', 'Only local', ...
                'In both - content differs', 'In both'});
        end

        function testComparisonRowsEmpty(testCase)
            rows = ndi.gui.nav.cloudComparison.comparisonRows(struct());
            testCase.verifySize(rows, [0 2]);
        end

        function testActionSpecsCoverEverySyncMode(testCase)
            specs = ndi.gui.nav.cloudComparison.actionSpecs();
            modes = enumeration('ndi.cloud.sync.enum.SyncMode');
            names = arrayfun(@(m) func2str(m.Function), modes, 'UniformOutput', false);
            names = erase(names, 'ndi.cloud.sync.');
            testCase.verifyEqual(sort({specs.Mode}), sort(names(:)'));
            % Only the mirrors delete, and they are the destructive ones.
            testCase.verifyEqual(sort({specs([specs.Destructive]).Mode}), ...
                {'mirrorFromRemote', 'mirrorToRemote'});
        end

        function testActionSpecRejectsUnknownMode(testCase)
            testCase.verifyError(@() ndi.gui.nav.cloudComparison.actionSpec('nope'), ...
                'NDI:cloudComparison:BadMode');
        end

        function testMirrorWarningNamesCountsAndPlaces(testCase)
            r = struct('remote_only_ids', ["a" "b" "c"], 'local_only_ids', "x", ...
                'common_ids', string.empty);
            msg = ndi.gui.nav.cloudComparison.mirrorWarning('mirrorFromRemote', r, '/data/copy1', 'CLOUD1');
            testCase.verifySubstring(msg, '1 document will be permanently DELETED from this local copy');
            testCase.verifySubstring(msg, '/data/copy1');
            testCase.verifySubstring(msg, 'CLOUD1');
            msg = ndi.gui.nav.cloudComparison.mirrorWarning('mirrorToRemote', r, '/data/copy1', 'CLOUD1');
            testCase.verifySubstring(msg, '3 documents will be permanently DELETED from the cloud dataset');
        end

        function testMirrorWarningWithoutReport(testCase)
            msg = ndi.gui.nav.cloudComparison.mirrorWarning('mirrorToRemote', [], '', '');
            testCase.verifySubstring(msg, 'permanently DELETED');
            testCase.verifyError(@() ndi.gui.nav.cloudComparison.mirrorWarning('uploadNew', [], '', ''), ...
                'NDI:cloudComparison:BadMode');
        end
    end
end
