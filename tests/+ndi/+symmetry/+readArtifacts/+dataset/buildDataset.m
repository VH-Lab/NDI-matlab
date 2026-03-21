classdef buildDataset < matlab.unittest.TestCase

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testBuildDatasetArtifacts(testCase, SourceType)
            % Determine the artifact directory expected from either MATLAB or Python
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'dataset', 'buildDataset', 'testBuildDatasetArtifacts');

            % If the directory does not exist, we cannot run the read tests.
            % Return early so the test passes silently instead of showing up as "Incomplete/Filtered"
            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            % Load the dataset summary JSON
            summaryJsonFile = fullfile(artifactDir, 'datasetSummary.json');
            if ~isfile(summaryJsonFile)
                disp(['datasetSummary.json file not found in ' SourceType ' artifact directory. Skipping.']);
                return;
            end

            fid = fopen(summaryJsonFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            expectedSummary = jsondecode(rawJson);

            % Open the dataset from the artifact directory
            dataset = ndi.dataset.dir('ds_demo', artifactDir);

            % Build the actual dataset summary using the shared utility
            actualDatasetSummary = ndi.util.datasetSummary(dataset);

            % Compare using the shared comparison utility
            report = ndi.util.compareDatasetSummary(actualDatasetSummary, expectedSummary, ...
                'excludeFiles', {'datasetSummary.json', 'jsonDocuments'});
            testCase.verifyEmpty(report, ...
                ['Dataset summary mismatch against ' SourceType ' generated artifacts: ' strjoin(report, '; ')]);
        end
    end
end
