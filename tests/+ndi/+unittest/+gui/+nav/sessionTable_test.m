classdef sessionTable_test < matlab.unittest.TestCase
    % SESSIONTABLE_TEST - Tests for ndi.gui.nav.sessionTable helpers.
    %
    % These run headless (no GUI): they cover the table kinds behind the
    % navigator's "Session > Tables" submenu and the text formatting of
    % table cells.

    methods (Test)
        function testTableKindsOrderAndFunctions(testCase)
            kinds = ndi.gui.nav.sessionTable.tableKinds();
            testCase.verifyEqual({kinds.Kind}, ...
                {'element', 'epoch', 'probe', 'subject', 'treatment'});
            testCase.verifyEqual({kinds.Label}, ...
                {'Elements...', 'Epochs...', 'Probes...', 'Subjects...', 'Treatments...'});
            testCase.verifyEqual(sort({kinds.Label}), {kinds.Label});
            for i = 1:numel(kinds)
                testCase.verifyNotEmpty(which(kinds(i).Function), kinds(i).Function);
                testCase.verifyTrue(isvarname(kinds(i).VariableName));
            end
        end

        function testKindInfo(testCase)
            info = ndi.gui.nav.sessionTable.kindInfo('Subject');
            testCase.verifyEqual(info.Kind, 'subject');
            testCase.verifyEqual(info.Title, 'Subject table');
            testCase.verifyError(@() ndi.gui.nav.sessionTable.kindInfo('nope'), ...
                'ndi:gui:nav:sessionTable:unknownKind');
        end

        function testSummaryText(testCase)
            f = @ndi.gui.nav.sessionTable.summaryText;
            testCase.verifyEqual(f('Probe table', table()), 'Probe table (0 rows)');
            testCase.verifyEqual(f('Probe table', table(1)), 'Probe table (1 row)');
            testCase.verifyEqual(f('Probe table', table([1;2])), 'Probe table (2 rows)');
        end

        function testCellText(testCase)
            f = @ndi.gui.nav.sessionTable.cellText;
            testCase.verifyEqual(f('abc'), 'abc');
            testCase.verifyEqual(f(""), '');
            testCase.verifyEqual(f(["a" "b"]), 'a, b');
            testCase.verifyEqual(f(3), '3');
            testCase.verifyEqual(f(NaN), '');
            testCase.verifyEqual(f([1 2]), '[1 2]');
            testCase.verifyEqual(f(true), 'true');
            testCase.verifyEqual(f([]), '');
            testCase.verifyEqual(f({'a', 2, ''}), 'a, 2');
            testCase.verifyEqual(f(struct('a', 1)), '<struct>');
        end

        function testTableCells(testCase)
            T = table({'s1'; 's2'}, [1; NaN], [1 2; 3 4], ...
                'VariableNames', {'Name', 'Value', 'Pair'});
            [names, data] = ndi.gui.nav.sessionTable.tableCells(T);
            testCase.verifyEqual(names, {'Name', 'Value', 'Pair'});
            testCase.verifyEqual(data, {'s1', '1', '[1 2]'; 's2', '', '[3 4]'});
        end

        function testTableCellsEmpty(testCase)
            [names, data] = ndi.gui.nav.sessionTable.tableCells(table());
            testCase.verifyEmpty(names);
            testCase.verifyEmpty(data);
        end
    end
end
