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

        function testShortClassName(testCase)
            f = @ndi.gui.nav.daqSystemBrowser.shortClassName;
            testCase.verifyEqual(f('ndi.daq.reader.mfdaq.intan'), 'intan');
            testCase.verifyEqual(f('struct'), 'struct');
            testCase.verifyEqual(f(''), '');
        end

        function testEpochLabels(testCase)
            labels = ndi.gui.nav.daqSystemBrowser.epochLabels([1 2], {'t00001', ''});
            testCase.verifyEqual(labels, {'Epoch 1  (t00001)', 'Epoch 2'});
        end

        function testEpochFileRowsMarksProbeMap(testCase)
            d = fullfile(tempdir, 't00001');
            files = {fullfile(d, 'reference.txt'), fullfile(d, 'data.rhd'), ...
                fullfile(d, 'vhintan_channelgrouping.txt')};
            patterns = {'reference.txt', '.*\.rhd\>', 'vhintan_channelgrouping.txt'};
            rows = ndi.gui.nav.daqSystemBrowser.epochFileRows(files, patterns, files{3});
            testCase.verifySize(rows, [3 3]);
            testCase.verifyEqual(rows(:, 1)', ...
                {'reference.txt', 'data.rhd', 'vhintan_channelgrouping.txt'});
            testCase.verifyEqual(rows{1, 2}, 'reference.txt');
            testCase.verifyEqual(rows{3, 3}, 'epoch probe map');
            testCase.verifyEmpty(rows{1, 3});
        end

        function testEpochFileRowsDefaultProbeMapGetsOwnRow(testCase)
            d = fullfile(tempdir, 'no_such_epoch_dir');
            files = {fullfile(d, 'data.rhd')};
            pm = fullfile(d, '.data.rhd.epochprobemap.ndi');
            rows = ndi.gui.nav.daqSystemBrowser.epochFileRows(files, {}, pm);
            testCase.verifySize(rows, [2 3]);
            testCase.verifyEqual(rows{2, 1}, '.data.rhd.epochprobemap.ndi');
            testCase.verifySubstring(rows{2, 3}, 'default location');
            testCase.verifySubstring(rows{2, 3}, 'not found');
        end

        function testEpochFileRowsEmpty(testCase)
            rows = ndi.gui.nav.daqSystemBrowser.epochFileRows({}, {}, '');
            testCase.verifySubstring(rows{1, 1}, 'no files');
        end

        function testMatchingPatternNoMatch(testCase)
            testCase.verifyEqual( ...
                ndi.gui.nav.daqSystemBrowser.matchingPattern({'a.txt'}, 'b.dat'), '');
            testCase.verifyEqual( ...
                ndi.gui.nav.daqSystemBrowser.matchingPattern({}, 'b.dat'), '');
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
