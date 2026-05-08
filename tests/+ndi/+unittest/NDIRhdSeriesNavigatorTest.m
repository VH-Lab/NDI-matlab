classdef NDIRhdSeriesNavigatorTest < matlab.unittest.TestCase
    %NDIRHDSERIESNAVIGATORTEST Unit tests for ndi.file.navigator.rhd_series
    % and ndi.file.navigator.rhd_series_epochdir.
    %
    %   Builds a synthetic session directory containing prefix-grouped
    %   .rhd files (with a YYYYMMDDHHMMSS.msec timestamp suffix) and
    %   verifies that:
    %     - one epoch is returned per unique prefix,
    %     - the earliest .rhd file in each prefix group is the one
    %       returned by the navigator,
    %     - ancillary files matched via the '#' substitution syntax
    %       are added to the epoch file list,
    %     - epochs missing a required ancillary are skipped,
    %     - the epochdir variant performs the same matching independently
    %       inside each first-level subdirectory.

    properties (Constant, Access = private)
        Stamps = {'20240101120000.000', '20240101120100.000', '20240102140000.000'};
    end

    methods (TestClassSetup)
        function initializeMksqliteNoOutput(~)
            ndi.test.helper.initializeMksqliteNoOutput()
        end
    end

    methods (Test)
        function testFlatGroupsByPrefix(testCase)
            sess = testCase.makeFlatSession();

            fn = ndi.file.navigator.rhd_series(sess, ...
                {'#_\d{14}\.\d+\.rhd\>'});

            n = numepochs(fn);
            testCase.verifyEqual(n, 2, ...
                'Expected one epoch per unique prefix.');
        end

        function testFlatReturnsEarliestFile(testCase)
            sess = testCase.makeFlatSession();

            fn = ndi.file.navigator.rhd_series(sess, ...
                {'#_\d{14}\.\d+\.rhd\>'});

            ids = arrayfun(@(k) string(epochid(fn, k)), 1:numepochs(fn));
            testCase.verifyTrue(any(ids == "myExp_001"));
            testCase.verifyTrue(any(ids == "myExp_002"));

            files = getepochfiles(fn, find(ids == "myExp_001", 1));
            [~, name, ext] = fileparts(files{1});
            testCase.verifyEqual([name ext], ...
                'myExp_001_20240101120000.000.rhd', ...
                'Expected earliest timestamp to be selected.');
        end

        function testFlatAncillaryFilesAreAttached(testCase)
            sess = testCase.makeFlatSession();
            fid = fopen(fullfile(sess.path(), 'myExp_001.epochprobemap.ndi'), 'w');
            fclose(fid);
            fid = fopen(fullfile(sess.path(), 'myExp_002.epochprobemap.ndi'), 'w');
            fclose(fid);

            fn = ndi.file.navigator.rhd_series(sess, ...
                {'#_\d{14}\.\d+\.rhd\>', '#\.epochprobemap\.ndi\>'});

            testCase.verifyEqual(numepochs(fn), 2);
            for k = 1:numepochs(fn)
                files = getepochfiles(fn, k);
                testCase.verifyEqual(numel(files), 2, ...
                    'Each epoch should have rhd plus ancillary file.');
                testCase.verifyTrue(endsWith(files{2}, '.epochprobemap.ndi'));
            end
        end

        function testFlatAncillaryPicksEarliestWhenMultipleMatch(testCase)
            sess = testCase.makeFlatSession();
            % Two probemap files for the same prefix; we should get the
            % earlier timestamp regardless of dir() ordering.
            for stamp = ["20240101120100.000", "20240101120000.000"]
                fid = fopen(fullfile(sess.path(), ...
                    ['myExp_001_' char(stamp) '._epochprobemap.txt']), 'w');
                fclose(fid);
            end
            fid = fopen(fullfile(sess.path(), ...
                'myExp_002_20240102140000.000._epochprobemap.txt'), 'w');
            fclose(fid);

            fn = ndi.file.navigator.rhd_series(sess, ...
                {'#_\d{14}\.\d+\.rhd\>', '#_\d{14}\.\d+\._epochprobemap\.txt\>'});

            ids = arrayfun(@(k) string(epochid(fn, k)), 1:numepochs(fn));
            files = getepochfiles(fn, find(ids == "myExp_001", 1));
            testCase.verifyEqual(numel(files), 2);
            [~, name, ext] = fileparts(files{2});
            testCase.verifyEqual([name ext], ...
                'myExp_001_20240101120000.000._epochprobemap.txt', ...
                'Ancillary should select the earliest matching file.');
        end

        function testFlatEpochSkippedIfAncillaryMissing(testCase)
            sess = testCase.makeFlatSession();
            fid = fopen(fullfile(sess.path(), 'myExp_001.epochprobemap.ndi'), 'w');
            fclose(fid);
            % Note: no ancillary for myExp_002 -> that epoch should drop.

            fn = ndi.file.navigator.rhd_series(sess, ...
                {'#_\d{14}\.\d+\.rhd\>', '#\.epochprobemap\.ndi\>'});

            testCase.verifyEqual(numepochs(fn), 1, ...
                'Epoch with missing ancillary should be skipped.');
            testCase.verifyEqual(epochid(fn, 1), 'myExp_001');
        end

        function testEpochdirOneEpochPerSubdir(testCase)
            sess = testCase.makeEpochdirSession();

            fn = ndi.file.navigator.rhd_series_epochdir(sess, ...
                {'#_\d{14}\.\d+\.rhd\>'});

            testCase.verifyEqual(numepochs(fn), 2, ...
                'Expected one epoch per subdirectory.');

            ids = arrayfun(@(k) string(epochid(fn, k)), 1:numepochs(fn));
            testCase.verifyTrue(any(ids == "epoch1"));
            testCase.verifyTrue(any(ids == "epoch2"));
        end

        function testEpochdirReturnsEarliestPerSubdir(testCase)
            sess = testCase.makeEpochdirSession();

            fn = ndi.file.navigator.rhd_series_epochdir(sess, ...
                {'#_\d{14}\.\d+\.rhd\>'});

            ids = arrayfun(@(k) string(epochid(fn, k)), 1:numepochs(fn));
            files = getepochfiles(fn, find(ids == "epoch1", 1));
            [~, name, ext] = fileparts(files{1});
            testCase.verifyEqual([name ext], ...
                'myExp_001_20240101120000.000.rhd');
        end

        function testEpochdirAncillaryWithinSubdir(testCase)
            sess = testCase.makeEpochdirSession();
            for sub = ["epoch1", "epoch2"]
                base = fullfile(sess.path(), char(sub));
                prefix = char("myExp_00" + extractAfter(sub, "epoch"));
                fid = fopen(fullfile(base, [prefix '.epochprobemap.ndi']), 'w');
                fclose(fid);
            end

            fn = ndi.file.navigator.rhd_series_epochdir(sess, ...
                {'#_\d{14}\.\d+\.rhd\>', '#\.epochprobemap\.ndi\>'});

            testCase.verifyEqual(numepochs(fn), 2);
            for k = 1:numepochs(fn)
                files = getepochfiles(fn, k);
                testCase.verifyEqual(numel(files), 2);
                testCase.verifyTrue(endsWith(files{2}, '.epochprobemap.ndi'));
                [d1, ~] = fileparts(files{1});
                [d2, ~] = fileparts(files{2});
                testCase.verifyEqual(d1, d2, ...
                    'Ancillary should live in the same subdirectory as the rhd.');
            end
        end
    end

    methods (Access = private)
        function sess = makeFlatSession(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            stamps = testCase.Stamps;

            % Two prefixes, multiple files each, in arbitrary creation order.
            ordering = [3 1 2];   % create 1202 last so we can confirm sort, not creation, picks earliest
            for i = ordering
                fid = fopen(['myExp_001_' stamps{i} '.rhd'], 'w');
                fclose(fid);
            end
            fid = fopen('myExp_002_20240102140000.000.rhd', 'w'); fclose(fid);

            sess = ndi.session.dir('rhd_series_test', pwd);
        end

        function sess = makeEpochdirSession(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            stamps = testCase.Stamps;

            mkdir('epoch1');
            for i = [3 1 2]
                fid = fopen(fullfile('epoch1', ['myExp_001_' stamps{i} '.rhd']), 'w');
                fclose(fid);
            end

            mkdir('epoch2');
            fid = fopen(fullfile('epoch2', 'myExp_002_20240102140000.000.rhd'), 'w');
            fclose(fid);

            sess = ndi.session.dir('rhd_series_epochdir_test', pwd);
        end
    end
end
