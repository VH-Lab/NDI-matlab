classdef buildSession < ndi.unittest.session.buildSession

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
        function testBuildSessionArtifacts(testCase)
            % Determine the artifact directory
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'session', 'buildSession', 'testBuildSessionArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end

            % Store probes list BEFORE copying the session because `getprobes()`
            % generates new internal NDI documents that need to be captured.
            testCase.Session.getprobes();

            % Re-open the session before capturing documents.
            % `ndi.session.dir` generates internal documents when first instantiated on a directory.
            sessionPath = testCase.Session.path();
            testCase.Session = ndi.session.dir('exp1', sessionPath);

            % Create a comprehensive session summary (including probes, files, daqs, etc.)
            summary = ndi.util.sessionSummary(testCase.Session);
            summaryJsonStr = jsonencode(summary, 'ConvertInfAndNaN', true, 'PrettyPrint', true);

            % Copy the entire original NDI session folder into our persistent artifact directory
            % so that the Python test suite has access to the actual data files and the document database.
            % We copy before creating the directory so that copyfile correctly handles hidden folders like `.ndi`
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
