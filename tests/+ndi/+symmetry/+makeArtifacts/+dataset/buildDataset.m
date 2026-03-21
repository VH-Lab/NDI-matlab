classdef buildDataset < ndi.unittest.dataset.buildDataset

    methods (TestMethodTeardown)
        function teardownDataset(testCase)
            % OVERRIDE TEARDOWN:
            % By overriding the exact method name from the superclass `teardownDataset`,
            % we prevent the superclass from destroying the dataset and session.
            % The generated artifacts MUST persist in the tempdir so that the
            % Python test suite can read them.
        end
    end

    methods (Test)
        function testBuildDatasetArtifacts(testCase)
            % Determine the artifact directory
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'dataset', 'buildDataset', 'testBuildDatasetArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end

            dataset = testCase.Dataset;

            % Build the dataset summary using the shared utility
            datasetSummary = ndi.util.datasetSummary(dataset);

            % Encode to JSON
            summaryJsonStr = jsonencode(datasetSummary, 'ConvertInfAndNaN', true, 'PrettyPrint', true);

            % Get session list for artifact export below
            [~, id_list] = dataset.session_list();
            numSessions = numel(id_list);

            % Copy the entire dataset folder into our persistent artifact directory
            datasetPath = dataset.path;
            if isfolder(datasetPath)
                copyfile(datasetPath, artifactDir);
            else
                mkdir(artifactDir);
            end

            % Export jsonDocuments for each session in the dataset
            for i = 1:numSessions
                sess = dataset.open_session(id_list{i});
                sessionJsonDocsDir = fullfile(artifactDir, 'jsonDocuments', id_list{i});
                mkdir(sessionJsonDocsDir);

                docs = sess.database_search(ndi.query('base.id', 'regexp', '(.*)'));
                for j = 1:numel(docs)
                    jsonStr = jsonencode(docs{j}.document_properties, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
                    fid = fopen(fullfile(sessionJsonDocsDir, [docs{j}.id() '.json']), 'w');
                    if fid > 0
                        fprintf(fid, '%s', jsonStr);
                        fclose(fid);
                    else
                        error('Could not create document JSON file');
                    end
                end
            end

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
