classdef rhdSeriesNavigator < matlab.unittest.TestCase

    properties
        Session
        SessionPath
    end

    methods (TestMethodSetup)
        function setupRhdSeriesNavigator(testCase)
            testCase.SessionPath = fullfile(tempdir(), 'NDI', 'test_rhdSeriesNavigator');
            if isfolder(testCase.SessionPath)
                rmdir(testCase.SessionPath, 's');
            end
            mkdir(testCase.SessionPath);

            % Create two prefix groups of fake .rhd files
            % Group A: two .rhd files plus matching epochprobemap
            fclose(fopen(fullfile(testCase.SessionPath, 'A_20260101_120000.rhd'), 'w'));
            fclose(fopen(fullfile(testCase.SessionPath, 'A_20260101_120500.rhd'), 'w'));
            fclose(fopen(fullfile(testCase.SessionPath, 'A_20260101_120000._epochprobemap.txt'), 'w'));

            % Group B: two .rhd files plus matching epochprobemap
            fclose(fopen(fullfile(testCase.SessionPath, 'B_20260101_130000.rhd'), 'w'));
            fclose(fopen(fullfile(testCase.SessionPath, 'B_20260101_130500.rhd'), 'w'));
            fclose(fopen(fullfile(testCase.SessionPath, 'B_20260101_130000._epochprobemap.txt'), 'w'));

            testCase.Session = ndi.session.dir('exp1', testCase.SessionPath);
        end
    end

    methods (TestMethodTeardown)
        function teardownRhdSeriesNavigator(testCase)
            % OVERRIDE TEARDOWN:
            % Do nothing so artifacts persist for the Python test suite.
        end
    end

    methods (Test)
        function testRhdSeriesNavigator(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'file', 'rhdSeriesNavigator', 'testRhdSeriesNavigator');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Construct the navigator with series and ancillary patterns
            fileparameters = {'#_\d{8}_\d{6}\.rhd\>', '#_\d{8}_\d{6}\._epochprobemap\.txt\>'};
            nav = ndi.file.navigator.rhd_series(testCase.Session, fileparameters);

            % Run selectfilegroups_disk and gather epochids
            groups = nav.selectfilegroups_disk();
            testCase.verifyEqual(numel(groups), 2, 'Expected 2 epoch groups from rhd_series navigator.');

            epochInfo = struct('epochid', {}, 'files', {});
            for i = 1:numel(groups)
                eid = nav.epochid(i, groups{i});
                rel = cell(numel(groups{i}), 1);
                for j = 1:numel(groups{i})
                    [~, n, e] = fileparts(groups{i}{j});
                    rel{j} = [n e];
                end
                epochInfo(end+1).epochid = eid; %#ok<AGROW>
                epochInfo(end).files = rel;
            end

            % Copy on-disk fixture into the artifact dir so python can re-walk it
            fixtureDir = fullfile(artifactDir, 'fixture');
            mkdir(fixtureDir);
            entries = dir(testCase.SessionPath);
            entries = entries(~[entries.isdir]);
            for i = 1:numel(entries)
                if startsWith(entries(i).name, '.')
                    continue;
                end
                copyfile(fullfile(testCase.SessionPath, entries(i).name), ...
                    fullfile(fixtureDir, entries(i).name));
            end

            % Write the navigator document JSON
            navDoc = struct( ...
                'navigator_class',  'ndi.file.navigator.rhd_series', ...
                'fileparameters',   {fileparameters}, ...
                'epochs',           epochInfo);
            navJson = jsonencode(navDoc, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'rhd_series_navigator.json'), 'w');
            if fid > 0
                fprintf(fid, '%s', navJson);
                fclose(fid);
            else
                error('Could not create rhd_series_navigator.json file');
            end
        end
    end
end
