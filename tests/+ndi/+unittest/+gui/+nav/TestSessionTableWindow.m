classdef TestSessionTableWindow < ndi.unittest.session.buildSession
    % TESTSESSIONTABLEWINDOW - ndi.gui.nav.sessionTable on a real session
    %
    % Opens the "Session > Tables" window (hidden) on the example Intan
    % session built by ndi.unittest.session.buildSession, then checks the
    % window shows the ndi.fun.docTable table and that "Assign to
    % workspace..." and "Export CSV..." work when given a name / file.

    properties
        Window
    end

    methods (TestMethodSetup)
        function openWindow(testCase)
            testCase.Window = ndi.gui.nav.sessionTable(testCase.Session, ...
                'element', 'Visible', 'off');
            testCase.addTeardown(@() delete(testCase.Window.Figure));
        end
    end

    methods (Test)
        function testShowsTheTable(testCase)
            w = testCase.Window;
            testCase.verifyEqual(w.Kind, 'element');
            testCase.verifyClass(w.Table, 'table');
            testCase.verifyEqual(char(w.Figure.Name), ...
                ['Element table: ' char(testCase.Session.reference)]);
            [names, data] = ndi.gui.nav.sessionTable.tableCells(w.Table);
            testCase.verifyEqual(w.UITable.Data, data);
            if isempty(names)
                testCase.verifyEmpty(w.UITable.ColumnName);
            else
                testCase.verifyEqual(cellstr(w.UITable.ColumnName(:))', names);
            end
            labels = findall(w.Figure, 'Type', 'uilabel');
            testCase.verifyTrue(any(startsWith({labels.Text}, 'Element table (')));
        end

        function testAssignToWorkspace(testCase)
            name = 'ndiSessionTableTestVar';
            testCase.addTeardown(@() evalin('base', ['clear ' name]));
            got = testCase.Window.assignToWorkspace(name);
            testCase.verifyEqual(got, name);
            testCase.verifyEqual(evalin('base', name), testCase.Window.Table);
        end

        function testAssignRejectsBadName(testCase)
            got = testCase.verifyWarning(@() testCase.Window.assignToWorkspace('1bad'), ...
                'ndi:gui:nav:sessionTable:actionFailed');
            testCase.verifyEmpty(got);
        end

        function testExportCsv(testCase)
            f = [tempname '.csv'];
            testCase.addTeardown(@() delete(f));
            got = testCase.Window.exportCsv(f);
            testCase.verifyEqual(got, f);
            testCase.verifyTrue(isfile(f));
            if height(testCase.Window.Table) > 0
                T = readtable(f, 'Delimiter', ',');
                testCase.verifyEqual(height(T), height(testCase.Window.Table));
            end
        end

        function testOtherKindsBuild(testCase)
            % Every table kind opens on this session, or fails with an error
            % (e.g. no stimulators for the epoch table) - never a hang.
            kinds = ndi.gui.nav.sessionTable.tableKinds();
            for i = 1:numel(kinds)
                try
                    w = ndi.gui.nav.sessionTable(testCase.Session, kinds(i).Kind, ...
                        'Visible', 'off');
                    testCase.verifyClass(w.Table, 'table');
                    delete(w.Figure);
                catch ME
                    testCase.log(1, sprintf('%s: %s', kinds(i).Kind, ME.message));
                end
            end
        end
    end
end
