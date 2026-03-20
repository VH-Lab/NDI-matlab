classdef downloadIngested < matlab.unittest.TestCase

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testDownloadIngestedArtifacts(testCase, SourceType)
            % Determine the artifact directory expected from either MATLAB or Python
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'dataset', 'downloadIngested', 'testDownloadIngestedArtifacts');

            % If the directory does not exist, skip gracefully
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

            % The downloaded dataset lives inside the artifact directory
            datasetPath = fullfile(artifactDir, '69a8705aa9ab25373cdc6563');
            testCase.verifyTrue(isfolder(datasetPath), ...
                ['Expected dataset directory not found in ' SourceType ' artifacts.']);

            % Open the dataset from the artifact directory
            dataset = ndi.dataset.dir(datasetPath);

            % Build the actual dataset summary (with document counts)
            actualDatasetSummary = ndi.util.datasetSummary(dataset, ...
                'includeDocumentCounts', true);

            % Compare using the shared comparison utility
            report = ndi.util.compareDatasetSummary(actualDatasetSummary, expectedSummary, ...
                'excludeFiles', {'datasetSummary.json', 'jsonDocuments'});
            testCase.verifyEmpty(report, ...
                ['Dataset summary mismatch against ' SourceType ' generated artifacts: ' strjoin(report, '; ')]);
        end
    end
end
