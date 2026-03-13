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

            % Create directories
            if ~isfolder(artifactDir)
                mkdir(artifactDir);
            end

            jsonDocsDir = fullfile(artifactDir, 'jsonDocuments');
            if ~isfolder(jsonDocsDir)
                mkdir(jsonDocsDir);
            end

            % Copy the entire original NDI session folder into our persistent artifact directory
            % so that the Python test suite has access to the actual data files and the document database.
            sessionPath = testCase.Session.path();
            if isfolder(sessionPath)
                copyfile(sessionPath, artifactDir);
            end

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

            % Store probes list
            probes = testCase.Session.getProbes();
            probeStructs = cell(1, numel(probes));
            for i=1:numel(probes)
                s = struct(...
                    'name', probes{i}.name, ...
                    'reference', probes{i}.reference, ...
                    'type', probes{i}.type, ...
                    'subject_id', probes{i}.subject_id ...
                );
                probeStructs{i} = s;
            end

            % If cell array is empty it gets converted to [] not an array in JSON, so explicitly empty it if so
            if isempty(probes)
                probeStructs = {};
            end

            probesJsonStr = jsonencode(probeStructs, 'ConvertInfAndNaN', true, 'PrettyPrint', true);

            fid = fopen(fullfile(artifactDir, 'probes.json'), 'w');
            if fid > 0
                fprintf(fid, '%s', probesJsonStr);
                fclose(fid);
            else
                error('Could not create probes.json file');
            end
        end
    end
end
