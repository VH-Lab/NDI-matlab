classdef daqSystemBrowser_test < matlab.unittest.TestCase
    % DAQSYSTEMBROWSER_TEST - Tests for ndi.gui.nav.daqSystemBrowser helpers.
    %
    % These run headless (no GUI). DAQ systems are stood in for by structs
    % carrying the same properties (name, filenavigator, daqreader,
    % daqmetadatareader), which describe() reads by name.

    methods (Test)
        function testFilematchListForms(testCase)
            f = @ndi.gui.nav.daqSystemBrowser.filematchList;
            testCase.verifyEqual(f([]), {});
            testCase.verifyEqual(f('.*\.rhd\>'), {'.*\.rhd\>'});
            testCase.verifyEqual(f({'#.rhd', '#.epochprobemap.txt'}), ...
                {'#.rhd', '#.epochprobemap.txt'});
            testCase.verifyEqual(f(struct('filematch', {{'a.ext', 'b.ext'}})), ...
                {'a.ext', 'b.ext'});
            testCase.verifyEqual(f(struct('other', 1)), {});
        end

        function testDescribeReadsNavigatorParameters(testCase)
            d = testCase.fakeDaq();
            s = ndi.gui.nav.daqSystemBrowser.describe(d);
            testCase.verifyEqual(s.name, 'intan1');
            testCase.verifyEqual(s.fileParameters, {'#.rhd', '#.epochprobemap.txt'});
            testCase.verifyEqual(s.epochProbeMapClass, 'ndi.epoch.epochprobemap_daqsystem');
            testCase.verifyEqual(s.epochProbeMapFileParameters, {'#.epochprobemap.txt'});
            testCase.verifyEqual(s.navigatorClass, 'struct');
        end

        function testDescribeToleratesMissingParts(testCase)
            s = ndi.gui.nav.daqSystemBrowser.describe(struct('name', 'bare'));
            testCase.verifyEqual(s.name, 'bare');
            testCase.verifyEmpty(s.fileParameters);
            testCase.verifyEmpty(s.navigatorClass);
            testCase.verifyEmpty(s.metadataReaders);
        end

        function testTableRows(testCase)
            info = ndi.gui.nav.daqSystemBrowser.describeAll({testCase.fakeDaq()});
            rows = ndi.gui.nav.daqSystemBrowser.tableRows(info);
            testCase.verifySize(rows, [1 8]);
            testCase.verifyEqual(rows{1, 5}, '#.rhd, #.epochprobemap.txt');
            testCase.verifyEqual(rows{1, 7}, '#.epochprobemap.txt');
            testCase.verifyEqual(rows{1, 8}, '(none)');
        end

        function testTableRowsDefaultEpochProbeMap(testCase)
            d = testCase.fakeDaq();
            d.filenavigator.epochprobemap_fileparameters = [];
            info = ndi.gui.nav.daqSystemBrowser.describeAll({d});
            rows = ndi.gui.nav.daqSystemBrowser.tableRows(info);
            testCase.verifySubstring(rows{1, 7}, 'default');
        end

        function testTableRowsNoDaqSystems(testCase)
            info = ndi.gui.nav.daqSystemBrowser.describeAll({});
            rows = ndi.gui.nav.daqSystemBrowser.tableRows(info);
            testCase.verifyEqual(rows{1, 1}, '(no DAQ systems)');
            testCase.verifySize(rows, [1 8]);
        end

        function testDetailLinesOnePatternPerLine(testCase)
            s = ndi.gui.nav.daqSystemBrowser.describe(testCase.fakeDaq());
            lines = ndi.gui.nav.daqSystemBrowser.detailLines(s);
            testCase.verifyTrue(any(strcmp(lines, '    #.rhd')));
            testCase.verifyTrue(any(strcmp(lines, '    #.epochprobemap.txt')));
        end
    end

    methods (Static, Access = private)
        function d = fakeDaq()
            nav = struct( ...
                'fileparameters', struct('filematch', {{'#.rhd', '#.epochprobemap.txt'}}), ...
                'epochprobemap_class', 'ndi.epoch.epochprobemap_daqsystem', ...
                'epochprobemap_fileparameters', struct('filematch', {{'#.epochprobemap.txt'}}));
            d = struct('name', 'intan1', 'filenavigator', nav, ...
                'daqreader', [], 'daqmetadatareader', {{}});
        end
    end
end
