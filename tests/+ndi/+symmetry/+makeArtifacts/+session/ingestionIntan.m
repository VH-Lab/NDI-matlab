classdef ingestionIntan < ndi.unittest.session.buildSession

    methods (TestMethodTeardown)
        function buildSessionTeardown(testCase)
            % OVERRIDE TEARDOWN:
            % By overriding the exact method name from the superclass `buildSessionTeardown`,
            % we prevent the superclass from destroying the session database.
            % The generated artifacts and the underlying NDI session database
            % MUST persist in the tempdir so that the Python test suite can read them.
        end
    end

    methods (Test)
        function testIngestionIntanArtifacts(testCase)
            % Determine the artifact directory
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'session', 'ingestionIntan', 'testIngestionIntanArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end

            % Store probes list BEFORE ingestion because `getprobes()`
            % generates new internal NDI documents that need to be captured.
            testCase.Session.getprobes();

            % Ingest the session
            [b, msg] = testCase.Session.ingest();
            assert(b, ['Ingestion failed: ' msg]);

            % Delete raw data files (keep only the .ndi database directory)
            sessionPath = testCase.Session.path();
            items = dir(sessionPath);
            for i = 1:numel(items)
                if ismember(items(i).name, {'.', '..'})
                    continue;
                end
                if strcmp(items(i).name, '.ndi')
                    continue;
                end
                fullPath = fullfile(sessionPath, items(i).name);
                if items(i).isdir
                    rmdir(fullPath, 's');
                else
                    delete(fullPath);
                end
            end

            % Clear the cache and re-open the session
            testCase.Session.cache.clear();
            testCase.Session = ndi.session.dir('exp1', sessionPath);

            % Create a comprehensive session summary (including probes, files, daqs, etc.)
            summary = ndi.util.sessionSummary(testCase.Session);
            summaryJsonStr = jsonencode(summary, 'ConvertInfAndNaN', true, 'PrettyPrint', true);

            % Copy the entire session folder into our persistent artifact directory
            if isfolder(sessionPath)
                copyfile(sessionPath, artifactDir);
            else
                mkdir(artifactDir);
            end

            jsonDocsDir = fullfile(artifactDir, 'jsonDocuments');
            mkdir(jsonDocsDir);

            % Store JSON conversion of all NDI documents
            docs = testCase.Session.database_search(ndi.query('base.id', 'regexp', '(.*)'));
            for i=1:numel(docs)
                jsonStr = jsonencode(docs{i}.document_properties, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
                fid = fopen(fullfile(jsonDocsDir, [docs{i}.id() '.json']), 'w');
                if fid > 0
                    fprintf(fid, '%s', jsonStr);
                    fclose(fid);
                else
                    error('Could not create document JSON file');
                end
            end

            % Write out session summary JSON
            fid = fopen(fullfile(artifactDir, 'sessionSummary.json'), 'w');
            if fid > 0
                fprintf(fid, '%s', summaryJsonStr);
                fclose(fid);
            else
                error('Could not create sessionSummary.json file');
            end
        end
    end
end
