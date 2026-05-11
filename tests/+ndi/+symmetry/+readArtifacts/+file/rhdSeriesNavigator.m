classdef rhdSeriesNavigator < matlab.unittest.TestCase

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testRhdSeriesNavigator(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'file', 'rhdSeriesNavigator', 'testRhdSeriesNavigator');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            navJsonFile = fullfile(artifactDir, 'rhd_series_navigator.json');
            testCase.assertTrue(isfile(navJsonFile), ...
                ['rhd_series_navigator.json missing in ' SourceType ' artifact dir.']);

            fid = fopen(navJsonFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            expected = jsondecode(rawJson);

            testCase.verifyEqual(char(expected.navigator_class), 'ndi.file.navigator.rhd_series', ...
                ['Navigator class mismatch in ' SourceType '.']);

            fixtureDir = fullfile(artifactDir, 'fixture');
            testCase.assertTrue(isfolder(fixtureDir), ...
                ['fixture directory missing in ' SourceType '.']);

            % Re-walk the on-disk fixture with a fresh navigator
            sessionPath = fullfile(tempdir(), 'NDI', 'test_rhdSeriesNavigator_read');
            if isfolder(sessionPath)
                rmdir(sessionPath, 's');
            end
            mkdir(sessionPath);
            entries = dir(fixtureDir);
            entries = entries(~[entries.isdir]);
            for i = 1:numel(entries)
                if startsWith(entries(i).name, '.')
                    continue;
                end
                copyfile(fullfile(fixtureDir, entries(i).name), ...
                    fullfile(sessionPath, entries(i).name));
            end
            session = ndi.session.dir('exp1', sessionPath);

            if iscell(expected.fileparameters)
                fileparameters = expected.fileparameters;
            else
                fileparameters = cellstr(expected.fileparameters);
                fileparameters = reshape(fileparameters, 1, []);
            end
            nav = ndi.file.navigator.rhd_series(session, fileparameters);
            groups = nav.selectfilegroups_disk();

            testCase.verifyEqual(numel(groups), numel(expected.epochs), ...
                ['Number of epoch groups mismatch in ' SourceType '.']);

            actualIds = cell(1, numel(groups));
            for i = 1:numel(groups)
                actualIds{i} = nav.epochid(i, groups{i});
            end

            expectedIds = cell(1, numel(expected.epochs));
            for i = 1:numel(expected.epochs)
                expectedIds{i} = char(expected.epochs(i).epochid);
            end

            testCase.verifyEqual(sort(actualIds), sort(expectedIds), ...
                ['Epoch ids mismatch in ' SourceType '.']);

            % Compare group structure: first file per group as basename
            actualFirsts = cell(1, numel(groups));
            for i = 1:numel(groups)
                [~, n, e] = fileparts(groups{i}{1});
                actualFirsts{i} = [n e];
            end
            expectedFirsts = cell(1, numel(expected.epochs));
            for i = 1:numel(expected.epochs)
                files = expected.epochs(i).files;
                if iscell(files)
                    first = files{1};
                else
                    first = files(1, :);
                end
                expectedFirsts{i} = char(first);
            end
            testCase.verifyEqual(sort(actualFirsts), sort(expectedFirsts), ...
                ['Group first-file mismatch in ' SourceType '.']);
        end
    end
end
