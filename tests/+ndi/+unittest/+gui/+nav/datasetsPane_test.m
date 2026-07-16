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
    end
end
