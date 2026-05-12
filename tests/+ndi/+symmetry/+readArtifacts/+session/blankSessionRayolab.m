classdef blankSessionRayolab < matlab.unittest.TestCase

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testBlankSessionRayolab(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'session', 'blankSessionRayolab', 'testBlankSessionRayolab');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            % Load the NDI session
            session = ndi.session.dir('exp1', artifactDir);

            % Verify DAQ systems
            daqSystems = session.daqsystem_load('name', '(.*)');
            if isempty(daqSystems)
                daqSystems = {};
            elseif ~iscell(daqSystems)
                daqSystems = {daqSystems};
            end
            testCase.verifyEqual(numel(daqSystems), 2, ...
                ['Expected 2 DAQ systems in ' SourceType ' rayolab session.']);

            expectedNames = {'rayo_intanSeries', 'rayo_stim'};
            actualNames = cell(1, numel(daqSystems));
            for i = 1:numel(daqSystems)
                actualNames{i} = daqSystems{i}.name;
            end
            for i = 1:numel(expectedNames)
                testCase.verifyTrue(any(strcmp(actualNames, expectedNames{i})), ...
                    ['Expected DAQ system ' expectedNames{i} ' not found in ' SourceType '.']);
            end

            % Each DAQ system should use ndi.file.navigator.rhd_series as its file navigator
            for i = 1:numel(daqSystems)
                nav = daqSystems{i}.filenavigator;
                testCase.verifyEqual(class(nav), 'ndi.file.navigator.rhd_series', ...
                    ['DAQ system ' daqSystems{i}.name ' should use ndi.file.navigator.rhd_series in ' SourceType '.']);
            end

            % Verify session summary
            summaryJsonFile = fullfile(artifactDir, 'sessionSummary.json');
            if ~isfile(summaryJsonFile)
                disp(['sessionSummary.json file not found in ' SourceType ' artifact directory. Skipping summary comparison.']);
            else
                fid = fopen(summaryJsonFile, 'r');
                rawJson = fread(fid, inf, '*char')';
                fclose(fid);
                expectedSummary = jsondecode(rawJson);

                actualSummary = ndi.util.sessionSummary(session);

                report = ndi.util.compareSessionSummary(actualSummary, expectedSummary, 'excludeFiles', {'sessionSummary.json', 'jsonDocuments'});
                testCase.verifyEmpty(report, ['Session summary mismatch against ' SourceType ' generated artifacts.']);
            end
        end
    end
end
