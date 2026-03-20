classdef downloadIngested < matlab.unittest.TestCase

    methods (Test)
        function testDownloadIngestedArtifacts(testCase)
            % Determine the artifact directory
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'dataset', 'downloadIngested', 'testDownloadIngestedArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Look for a pre-downloaded archive (placed by CI workflow step)
            % or download it via curl as a fallback for local runs.
            tgzFile = fullfile(tempdir(), '69a8705aa9ab25373cdc6563.tgz');
            if ~isfile(tgzFile)
                tgzUrl = 'https://github.com/Waltham-Data-Science/file-passing/raw/refs/heads/main/69a8705aa9ab25373cdc6563.tgz';
                command = sprintf('curl -L -o "%s" "%s"', tgzFile, tgzUrl);
                [status, result] = system(command);
                if status ~= 0
                    error('Failed to download dataset archive: %s', result);
                end
            end
            testCase.addTeardown(@() delete(tgzFile));

            % Extract the archive into the artifact directory
            untar(tgzFile, artifactDir);

            % The extracted directory is an ndi.dataset.dir object
            datasetPath = fullfile(artifactDir, '69a8705aa9ab25373cdc6563');
            testCase.verifyTrue(isfolder(datasetPath), ...
                'Expected extracted directory 69a8705aa9ab25373cdc6563 not found.');

            % Open the dataset
            dataset = ndi.dataset.dir(datasetPath);

            % Build the dataset summary using the shared utility (with document counts)
            datasetSummary = ndi.util.datasetSummary(dataset, ...
                'includeDocumentCounts', true);

            % Encode to JSON
            summaryJsonStr = jsonencode(datasetSummary, 'ConvertInfAndNaN', true, 'PrettyPrint', true);

            % Write out dataset summary JSON
            fid = fopen(fullfile(artifactDir, 'datasetSummary.json'), 'w');
            if fid > 0
                fprintf(fid, '%s', summaryJsonStr);
                fclose(fid);
            else
                error('Could not create datasetSummary.json file');
            end
        end
    end
end
