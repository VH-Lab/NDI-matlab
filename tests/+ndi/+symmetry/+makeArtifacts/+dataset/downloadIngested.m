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
            % or download it as a fallback for local runs. Use the shared
            % cloud download helper rather than a bespoke system('curl') call
            % so the download goes through the single hardened path (which
            % resets LD_LIBRARY_PATH so the OS curl is not broken by MATLAB's
            % bundled libraries).
            tgzFile = fullfile(tempdir(), '69a8705aa9ab25373cdc6563.tgz');
            if ~isfile(tgzFile)
                tgzUrl = 'https://github.com/Waltham-Data-Science/file-passing/raw/refs/heads/main/69a8705aa9ab25373cdc6563.tgz';
                [downloadOK, downloadMsg] = ndi.cloud.api.files.getFile(tgzUrl, tgzFile, 'useCurl', true);
                if ~downloadOK
                    error('Failed to download dataset archive: %s', char(string(downloadMsg)));
                end
            end
            testCase.addTeardown(@() delete(tgzFile));

            % Extract the archive into the artifact directory
            untar(tgzFile, artifactDir);

            % Remove macOS resource fork files (._*) that may be in the archive;
            % these are invisible metadata files and should not appear in file listings.
            dotUnderscoreFiles = dir(fullfile(artifactDir, '**', '._*'));
            for k = 1:numel(dotUnderscoreFiles)
                delete(fullfile(dotUnderscoreFiles(k).folder, dotUnderscoreFiles(k).name));
            end

            % Find the extracted directory (expect exactly one folder)
            entries = dir(artifactDir);
            subdirs = entries([entries.isdir] & ~ismember({entries.name}, {'.', '..'}));
            testCase.verifyEqual(numel(subdirs), 1, ...
                sprintf('Expected exactly one directory in extracted archive, found %d.', numel(subdirs)));
            datasetPath = fullfile(artifactDir, subdirs(1).name);
            testCase.verifyTrue(isfolder(datasetPath), ...
                'Expected extracted dataset directory not found.');

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
