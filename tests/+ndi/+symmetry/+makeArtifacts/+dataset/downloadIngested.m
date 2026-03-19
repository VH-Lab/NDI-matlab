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

            % Get session list from dataset
            [ref_list, id_list] = dataset.session_list();
            numSessions = numel(ref_list);

            % Build lightweight session summaries for each session.
            % This dataset has thousands of documents, so calling the full
            % ndi.util.sessionSummary (which runs getprobes, daqsystem_load,
            % epochnodes) would take 20+ minutes. Instead, capture the
            % essential metadata: reference, ID, files, and document count.
            sessionSummaries = cell(1, numSessions);
            documentCounts = struct();
            for i = 1:numSessions
                sess = dataset.open_session(id_list{i});

                summary = struct();
                summary.reference = sess.reference;
                summary.sessionId = sess.id();

                session_path = sess.path();
                if isfolder(session_path)
                    d = dir(session_path);
                    d = d(~ismember({d.name}, {'.', '..'}));
                    summary.files = {d.name};
                else
                    summary.files = {};
                end

                dot_ndi_path = fullfile(session_path, '.ndi');
                if isfolder(dot_ndi_path)
                    d_ndi = dir(dot_ndi_path);
                    d_ndi = d_ndi(~ismember({d_ndi.name}, {'.', '..'}));
                    summary.filesInDotNDI = {d_ndi.name};
                else
                    summary.filesInDotNDI = {};
                end

                docs = sess.database_search(ndi.query('base.id', 'regexp', '(.*)'));
                documentCounts.(id_list{i}) = numel(docs);

                sessionSummaries{i} = summary;
            end

            % Build the dataset summary structure
            datasetSummary = struct();
            datasetSummary.numSessions = numSessions;
            datasetSummary.references = ref_list;
            datasetSummary.sessionIds = id_list;
            datasetSummary.sessionSummaries = sessionSummaries;
            datasetSummary.documentCounts = documentCounts;

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
