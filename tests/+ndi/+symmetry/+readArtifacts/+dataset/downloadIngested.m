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

            % Find the dataset directory (expect exactly one folder)
            entries = dir(artifactDir);
            subdirs = entries([entries.isdir] & ~ismember({entries.name}, {'.', '..'}));
            testCase.verifyEqual(numel(subdirs), 1, ...
                ['Expected exactly one directory in ' SourceType ' artifacts, found ' num2str(numel(subdirs)) '.']);
            datasetPath = fullfile(artifactDir, subdirs(1).name);
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
