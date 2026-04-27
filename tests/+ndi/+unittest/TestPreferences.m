classdef TestPreferences < matlab.unittest.TestCase
    % TESTPREFERENCES - unit tests for ndi.preferences and a smoke test
    % for the ndi.gui.preferencesEditor.
    %
    % The preferences singleton persists to a JSON file in MATLAB's
    % prefdir, so each test snapshots the current values in
    % TestMethodSetup and restores them in TestMethodTeardown to avoid
    % clobbering whatever the developer had configured.

    properties
        Snapshot   % struct array with fields: path, value
    end

    methods (TestMethodSetup)
        function snapshotPreferences(testCase)
            items = ndi.preferences.list();
            snap = repmat(struct('path', '', 'value', []), 1, numel(items));
            for i = 1:numel(items)
                snap(i).path  = ndi.unittest.TestPreferences.itemPath(items(i));
                snap(i).value = items(i).Value;
            end
            testCase.Snapshot = snap;
        end
    end

    methods (TestMethodTeardown)
        function restorePreferences(testCase)
            for i = 1:numel(testCase.Snapshot)
                try
                    ndi.preferences.set( ...
                        testCase.Snapshot(i).path, ...
                        testCase.Snapshot(i).value);
                catch
                    % Swallow restore failures; teardown should not mask
                    % the original test failure.
                end
            end
        end
    end

    methods (Test)

        function testGetSingletonReturnsSameInstance(testCase)
            p1 = ndi.preferences.getSingleton();
            p2 = ndi.preferences.getSingleton();
            testCase.verifyClass(p1, 'ndi.preferences');
            testCase.verifyTrue(p1 == p2, ...
                'getSingleton should return the same handle each call.');
        end

        function testListReturnsStructArrayWithExpectedFields(testCase)
            items = ndi.preferences.list();
            testCase.verifyClass(items, 'struct');
            testCase.verifyGreaterThanOrEqual(numel(items), 3);
            required = {'Category', 'Subcategory', 'Name', 'Value', ...
                        'DefaultValue', 'Description', 'Type'};
            for k = 1:numel(required)
                testCase.verifyTrue(isfield(items, required{k}), ...
                    sprintf('Items struct missing field "%s".', required{k}));
            end
        end

        function testCloudDefaultsArePresent(testCase)
            ndi.preferences.reset();
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Download.Max_Document_Batch_Count'), ...
                10000);
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Upload.Max_Document_Batch_Count'), ...
                100000);
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Upload.Max_File_Batch_Size'), ...
                500e6);
        end

        function testSetThenGetRoundTrips(testCase)
            ndi.preferences.set('Cloud.Download.Max_Document_Batch_Count', 42);
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Download.Max_Document_Batch_Count'), ...
                42);
        end

        function testResetReturnsToDefault(testCase)
            path = 'Cloud.Upload.Max_File_Batch_Size';
            ndi.preferences.set(path, 1);
            testCase.assertEqual(ndi.preferences.get(path), 1);
            ndi.preferences.reset(path);
            testCase.verifyEqual(ndi.preferences.get(path), 500e6);
        end

        function testResetAllReturnsAllToDefaults(testCase)
            ndi.preferences.set('Cloud.Download.Max_Document_Batch_Count', 1);
            ndi.preferences.set('Cloud.Upload.Max_Document_Batch_Count',   2);
            ndi.preferences.set('Cloud.Upload.Max_File_Batch_Size',        3);
            ndi.preferences.reset();
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Download.Max_Document_Batch_Count'), ...
                10000);
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Upload.Max_Document_Batch_Count'), ...
                100000);
            testCase.verifyEqual( ...
                ndi.preferences.get('Cloud.Upload.Max_File_Batch_Size'), ...
                500e6);
        end

        function testHasReportsRegisteredPaths(testCase)
            testCase.verifyTrue(ndi.preferences.has( ...
                'Cloud.Upload.Max_File_Batch_Size'));
            testCase.verifyFalse(ndi.preferences.has( ...
                'NotACategory.NotASub.NotAName'));
            % Malformed paths should be reported as not-present, not throw.
            testCase.verifyFalse(ndi.preferences.has('JustOneToken'));
        end

        function testUnknownPathThrows(testCase)
            testCase.verifyError( ...
                @() ndi.preferences.get('Cloud.Foo.Bar'), ...
                'NDI:preferences:unknownPreference');
            testCase.verifyError( ...
                @() ndi.preferences.set('Cloud.Foo.Bar', 1), ...
                'NDI:preferences:unknownPreference');
        end

        function testInvalidPathThrows(testCase)
            testCase.verifyError( ...
                @() ndi.preferences.get('JustOneToken'), ...
                'NDI:preferences:invalidPath');
            testCase.verifyError( ...
                @() ndi.preferences.get('Too.Many.Levels.For.Us'), ...
                'NDI:preferences:invalidPath');
        end

        function testFilenameLivesInPrefdir(testCase)
            f = ndi.preferences.filename();
            testCase.verifyClass(f, 'char');
            testCase.verifyTrue(startsWith(f, prefdir), ...
                sprintf('Expected filename to start with prefdir (%s) but got %s', ...
                    prefdir, f));
        end

        function testSetPersistsToJsonFile(testCase)
            path = 'Cloud.Download.Max_Document_Batch_Count';
            ndi.preferences.set(path, 12345);

            filename = ndi.preferences.filename();
            testCase.assertTrue(isfile(filename), ...
                'Preferences file should exist after a set call.');

            S = jsondecode(fileread(filename));
            testCase.verifyEqual( ...
                S.Cloud__Download__Max_Document_Batch_Count, 12345);
        end

        function testEditorSmoke(testCase)
            % Smoke test: open the editor, check the major widgets are
            % present, then close it so it doesn't linger after the run.
            fig = ndi.gui.preferencesEditor();
            cleanup = onCleanup( ...
                @() ndi.unittest.TestPreferences.deleteIfValid(fig)); %#ok<NASGU>

            drawnow;

            testCase.assertNotEmpty(fig);
            testCase.verifyTrue(isvalid(fig));
            testCase.verifyClass(fig, 'matlab.ui.Figure');

            tree = findobj(fig, 'Tag', 'ndiPrefTree');
            testCase.assertNotEmpty(tree, ...
                'Editor should expose a uitree tagged ndiPrefTree.');
            testCase.verifyGreaterThanOrEqual(numel(tree.Children), 1);

            % "Cloud" should be one of the top-level category nodes.
            childTexts = arrayfun(@(c) string(c.Text), tree.Children);
            testCase.verifyTrue(any(childTexts == "Cloud"), ...
                'Expected a "Cloud" category node in the tree.');

            rightPanel = findobj(fig, 'Tag', 'ndiPrefRightPanel');
            testCase.assertNotEmpty(rightPanel, ...
                'Editor should expose a uipanel tagged ndiPrefRightPanel.');
            testCase.verifyGreaterThanOrEqual( ...
                numel(rightPanel.Children), 1, ...
                'Right panel should be populated after initial selection.');

            delete(fig);
            testCase.verifyFalse(isvalid(fig), ...
                'Figure handle should become invalid after delete.');
        end

    end

    methods (Static, Access = private)

        function p = itemPath(item)
            if isempty(item.Subcategory)
                p = sprintf('%s.%s', item.Category, item.Name);
            else
                p = sprintf('%s.%s.%s', ...
                    item.Category, item.Subcategory, item.Name);
            end
        end

        function deleteIfValid(fig)
            if ~isempty(fig) && isvalid(fig)
                delete(fig);
            end
        end

    end
end
