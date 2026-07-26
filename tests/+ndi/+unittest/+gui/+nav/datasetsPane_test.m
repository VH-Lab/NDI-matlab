classdef datasetsPane_test < matlab.unittest.TestCase
    % DATASETSPANE_TEST - Tests for ndi.gui.nav.datasetsPane helpers.
    %
    % These run headless (no GUI): they exercise the pure ordering logic that
    % lays out the session "Apps" context menu.

    methods (Test)
        function testEmptyAppsGivesEmptyEntries(testCase)
            entries = ndi.gui.nav.datasetsPane.orderAppMenu( ...
                struct('Label', {}, 'Category', {}));
            testCase.verifyEmpty(entries);
            testCase.verifyTrue(all(isfield(entries, {'Kind', 'Label', 'Apps'})));
        end

        function testTopLevelIsAlphabeticalAndInterleaved(testCase)
            % Uncategorized apps and category submenus share one alphabetical
            % order at the top level (case-insensitive).
            apps = struct( ...
                'Label',    {'Zebra',  'Apple',  'Mango',  'Banana'}, ...
                'Launch',   {@(s) [],  @(s) [],  @(s) [],  @(s) []}, ...
                'Category', {'',       'Fruits', '',       'Fruits'});
            entries = ndi.gui.nav.datasetsPane.orderAppMenu(apps);

            % Top level: category "Fruits", app "Mango", app "Zebra".
            testCase.verifyEqual(string({entries.Label}), ["Fruits","Mango","Zebra"]);
            testCase.verifyEqual(string({entries.Kind}), ["category","app","app"]);
        end

        function testAppsWithinCategoryAreAlphabetical(testCase)
            apps = struct( ...
                'Label',    {'Zebra',  'Apple',  'Banana'}, ...
                'Launch',   {@(s) [],  @(s) [],  @(s) []}, ...
                'Category', {'',       'Fruits', 'Fruits'});
            entries = ndi.gui.nav.datasetsPane.orderAppMenu(apps);

            fruits = entries(strcmp({entries.Kind}, 'category'));
            testCase.verifyNumElements(fruits, 1);
            testCase.verifyEqual(string({fruits.Apps.Label}), ["Apple","Banana"]);
        end

        function testAppEntryCarriesLaunchableApp(testCase)
            % An 'app' entry's Apps field is the launchable app struct itself.
            apps = struct('Label', {'Solo'}, 'Launch', {@(s) 42}, 'Category', {''});
            entries = ndi.gui.nav.datasetsPane.orderAppMenu(apps);
            testCase.verifyEqual(entries.Kind, 'app');
            testCase.verifyEqual(entries.Apps.Launch([]), 42);
        end

        function testMissingCategoryFieldTreatedAsTopLevel(testCase)
            % Apps discovered without any Category field stay at the top level.
            apps = struct('Label', {'Beta', 'Alpha'}, 'Launch', {@(s) [], @(s) []});
            entries = ndi.gui.nav.datasetsPane.orderAppMenu(apps);
            testCase.verifyEqual(string({entries.Label}), ["Alpha","Beta"]);
            testCase.verifyEqual(string({entries.Kind}), ["app","app"]);
        end

        %% Cloud context-menu status/result message helpers

        function testCloudCheckMessageRemotePluralisation(testCase)
            f = @(n) ndi.gui.nav.datasetsPane.cloudCheckMessage('remote', n);
            testCase.verifySubstring(f(0), 'no new documents on the cloud');
            testCase.verifySubstring(f(1), 'There is 1 document on the cloud');
            testCase.verifySubstring(f(3), 'There are 3 documents on the cloud');
        end

        function testCloudCheckMessageLocalPluralisation(testCase)
            f = @(n) ndi.gui.nav.datasetsPane.cloudCheckMessage('local', n);
            testCase.verifySubstring(f(0), 'no new local documents');
            testCase.verifySubstring(f(1), 'There is 1 local document');
            testCase.verifySubstring(f(2), 'There are 2 local documents');
        end

        function testCloudCheckMessageRejectsBadSide(testCase)
            testCase.verifyError( ...
                @() ndi.gui.nav.datasetsPane.cloudCheckMessage('sideways', 1), ...
                'NDI:datasetsPane:BadSide');
        end

        function testSyncResultMessageNoChanges(testCase)
            % A report with all-empty count fields reports "no changes".
            report = struct('uploaded_document_ids', string.empty, ...
                'downloaded_document_ids', string.empty);
            msg = ndi.gui.nav.datasetsPane.syncResultMessage(report);
            testCase.verifySubstring(msg, 'No changes were needed');
        end

        function testSyncResultMessageEmptyReportStruct(testCase)
            % A report struct with none of the count fields also reports
            % "no changes" rather than erroring.
            msg = ndi.gui.nav.datasetsPane.syncResultMessage(struct());
            testCase.verifySubstring(msg, 'No changes were needed');
        end

        function testSyncResultMessageCountsAndPluralisation(testCase)
            % Two-way-sync-shaped report: uploaded (plural) + downloaded (singular).
            report = struct( ...
                'uploaded_document_ids',   ["a" "b" "c"], ...
                'downloaded_document_ids', "z");
            msg = ndi.gui.nav.datasetsPane.syncResultMessage(report);
            testCase.verifySubstring(msg, '3 documents uploaded');
            testCase.verifySubstring(msg, '1 document downloaded');
        end

        %% Cloud menu enable/disable from cached status

        function testDatasetMenuEnableInCloud(testCase)
            % When the dataset is in the cloud, upload is disabled and the
            % link-requiring actions are enabled.
            [up, linked] = ndi.gui.nav.datasetsPane.datasetMenuEnable('incloud');
            testCase.verifyEqual(up, 'off');
            testCase.verifyEqual(linked, 'on');
        end

        function testDatasetMenuEnableNotInCloud(testCase)
            % When the dataset is not in the cloud, upload is enabled and the
            % link-requiring actions are disabled.
            [up, linked] = ndi.gui.nav.datasetsPane.datasetMenuEnable('notincloud');
            testCase.verifyEqual(up, 'on');
            testCase.verifyEqual(linked, 'off');
        end

        function testDatasetMenuEnableUnknownEnablesAll(testCase)
            % Before the status is checked, nothing is blocked.
            for state = ["unknown", "", "something else"]
                [up, linked] = ndi.gui.nav.datasetsPane.datasetMenuEnable(char(state));
                testCase.verifyEqual(up, 'on');
                testCase.verifyEqual(linked, 'on');
            end
        end

        function testSyncResultMessageReportsDeletions(testCase)
            % Mirror-shaped reports surface the deletion counts.
            fromRemote = struct( ...
                'downloaded_document_ids',    ["a" "b"], ...
                'deleted_local_document_ids', "x");
            msg = ndi.gui.nav.datasetsPane.syncResultMessage(fromRemote);
            testCase.verifySubstring(msg, '2 documents downloaded');
            testCase.verifySubstring(msg, '1 local document deleted');

            toRemote = struct( ...
                'uploaded_document_ids',       "a", ...
                'deleted_remote_document_ids', ["x" "y" "z"]);
            msg2 = ndi.gui.nav.datasetsPane.syncResultMessage(toRemote);
            testCase.verifySubstring(msg2, '1 document uploaded');
            testCase.verifySubstring(msg2, '3 remote documents deleted');
        end
    end
end
