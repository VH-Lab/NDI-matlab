classdef cloudDatasetBrowser_test < matlab.unittest.TestCase
    % CLOUDDATASETBROWSER_TEST - Tests for ndi.gui.nav.cloudDatasetBrowser.
    %
    % The static helpers run headless; the window test builds it hidden and
    % without contacting NDI Cloud ('Load', false).

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigatorCloudDatasetBrowser'));
        end
    end

    methods (Test)
        function testEntriesFromListReadsFields(testCase)
            list = struct('datasets', {{ ...
                struct('id', 'd1', 'name', 'Alpha', 'organizationId', 'o1', ...
                    'organizationName', 'Lab', 'documentCount', 12, 'fileCount', 3, ...
                    'createdAt', '2024-05-01T12:34:56.789Z', 'updatedAt', '2025-01-02T03:04:05Z'), ...
                struct('x_id', 'd2', 'name', 'beta'), ...
                struct('name', 'no id')}});
            e = ndi.gui.nav.cloudDatasetBrowser.entriesFromList(list);
            testCase.verifyNumElements(e, 2);   % the entry without an id is dropped
            testCase.verifyEqual(e(1).documentCount, 12);
            testCase.verifyTrue(e(1).detailed);
            testCase.verifyEqual(e(2).id, 'd2');
            testCase.verifyTrue(isnan(e(2).documentCount));
            testCase.verifyFalse(e(2).detailed);
        end

        function testMergeEntryFillsOnlyMissing(testCase)
            e = ndi.gui.nav.cloudDatasetBrowser.entryFromStruct(struct('id', 'd2', 'name', 'beta'));
            full = ndi.gui.nav.cloudDatasetBrowser.entryFromStruct(struct('id', 'd2', ...
                'name', 'renamed', 'documentCount', 5, 'fileCount', 0, 'createdAt', '2024-01-01T00:00:00Z'));
            m = ndi.gui.nav.cloudDatasetBrowser.mergeEntry(e, full);
            testCase.verifyEqual(m.name, 'beta');
            testCase.verifyEqual(m.documentCount, 5);
            testCase.verifyEqual(m.fileCount, 0);
            testCase.verifyEqual(m.createdAt, '2024-01-01T00:00:00Z');
        end

        function testSortEntries(testCase)
            e = ndi.gui.nav.cloudDatasetBrowser.entriesFromList({ ...
                struct('id', '1', 'name', 'b', 'documentCount', 5, 'createdAt', '2024-02-01T00:00:00Z'), ...
                struct('id', '2', 'name', 'A', 'documentCount', 9, 'createdAt', '2023-01-01T00:00:00Z'), ...
                struct('id', '3', 'name', 'c')});
            S = @(col, d) {ndi.gui.nav.cloudDatasetBrowser.sortEntries(e, col, d).id};
            testCase.verifyEqual(S('Name', false), {'2', '1', '3'});
            testCase.verifyEqual(S('Name', true), {'3', '1', '2'});
            % Unknown values sort last in both directions.
            testCase.verifyEqual(S('Documents', false), {'1', '2', '3'});
            testCase.verifyEqual(S('Documents', true), {'2', '1', '3'});
            testCase.verifyEqual(S('Created', false), {'2', '1', '3'});
            testCase.verifyError(@() ndi.gui.nav.cloudDatasetBrowser.sortEntries(e, 'Nope', false), ...
                'NDI:cloudDatasetBrowser:BadSortColumn');
        end

        function testDeleteAllowed(testCase)
            f = @ndi.gui.nav.cloudDatasetBrowser.deleteAllowed;
            testCase.verifyTrue(f('My Data', 'My Data', true, false, false));
            testCase.verifyTrue(f('My Data', '  My Data ', true, false, false));
            testCase.verifyFalse(f('My Data', 'my data', true, false, false));   % exact name
            testCase.verifyFalse(f('My Data', 'My Data', false, false, false));  % not ticked
            % A group organization needs the extra box as well.
            testCase.verifyFalse(f('My Data', 'My Data', true, true, false));
            testCase.verifyTrue(f('My Data', 'My Data', true, true, true));
            testCase.verifyFalse(f('', '', true, false, false));
        end

        function testIsGroupOrganization(testCase)
            f = @ndi.gui.nav.cloudDatasetBrowser.isGroupOrganization;
            testCase.verifyTrue(f(struct('id', 'o', 'name', 'Lab')));          % unknown -> group
            testCase.verifyFalse(f(struct('id', 'o', 'isPersonal', true)));
            testCase.verifyTrue(f(struct('id', 'o', 'isPersonal', false)));
            testCase.verifyFalse(f(struct('id', 'o', 'type', 'personal')));
            testCase.verifyFalse(f(struct('id', 'o', 'memberCount', 1)));
            testCase.verifyTrue(f(struct('id', 'o', 'memberCount', 4)));
        end

        function testDetailsAndFormatting(testCase)
            e = ndi.gui.nav.cloudDatasetBrowser.entryFromStruct(struct('id', 'd1', ...
                'name', 'Alpha', 'organizationName', 'Lab', 'documentCount', 12, ...
                'createdAt', '2024-05-01T12:34:56.789Z'));
            lines = strjoin(ndi.gui.nav.cloudDatasetBrowser.detailsText(e, true), newline);
            testCase.verifySubstring(lines, 'd1');
            testCase.verifySubstring(lines, '2024-05-01 12:34 UTC');
            testCase.verifySubstring(lines, 'Documents:     12');
            testCase.verifySubstring(lines, 'Files:         (unknown)');
            testCase.verifySubstring(lines, 'group organization');
        end

        function testWindowBuildsWithoutLoading(testCase)
            b = ndi.gui.nav.cloudDatasetBrowser('Visible', 'off', 'Load', false);
            testCase.addTeardown(@() delete(b.Figure));
            e = ndi.gui.nav.cloudDatasetBrowser.entriesFromList({ ...
                struct('id', 'd1', 'name', 'b'), struct('id', 'd2', 'name', 'a')});
            b.setEntries(e);
            testCase.verifySize(b.Table.Data, [2 6]);
            testCase.verifyEqual(b.Table.Data{1, 1}, 'a');   % sorted by Name
            testCase.verifyEqual(char(b.DeleteButton.Enable), 'off');
        end
    end
end
