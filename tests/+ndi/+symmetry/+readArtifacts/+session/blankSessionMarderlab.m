classdef blankSessionMarderlab < matlab.unittest.TestCase

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testBlankSessionMarderlab(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'session', 'blankSessionMarderlab', 'testBlankSessionMarderlab');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            % Load the NDI session
            session = ndi.session.dir('exp1', artifactDir);

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
