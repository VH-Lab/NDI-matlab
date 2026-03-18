classdef blankSessionMarderlab < matlab.unittest.TestCase

    properties
        Session
        SessionPath
    end

    methods (TestMethodSetup)
        function setupBlankSession(testCase)
            testCase.SessionPath = fullfile(tempdir(), 'NDI', 'test_blankSessionMarderlab');
            if isfolder(testCase.SessionPath)
                rmdir(testCase.SessionPath, 's');
            end
            mkdir(testCase.SessionPath);
            testCase.Session = ndi.setup.lab('marderlab', 'exp1', testCase.SessionPath);
        end
    end

    methods (TestMethodTeardown)
        function teardownBlankSession(testCase)
            % OVERRIDE TEARDOWN:
            % Do nothing so artifacts persist for the Python test suite.
        end
    end

    methods (Test)
        function testBlankSessionMarderlab(testCase)
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', 'matlabArtifacts', 'session', 'blankSessionMarderlab', 'testBlankSessionMarderlab');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end

            % Re-open the session to capture any auto-generated documents
            testCase.Session = ndi.session.dir('exp1', testCase.SessionPath);

            % Create session summary
            summary = ndi.util.sessionSummary(testCase.Session);
            summaryJsonStr = jsonencode(summary, 'ConvertInfAndNaN', true, 'PrettyPrint', true);

            % Copy entire session to artifact directory
            if isfolder(testCase.SessionPath)
                copyfile(testCase.SessionPath, artifactDir);
            else
                mkdir(artifactDir);
            end

            % Store JSON documents
            jsonDocsDir = fullfile(artifactDir, 'jsonDocuments');
            mkdir(jsonDocsDir);

            docs = testCase.Session.database_search(ndi.query('base.id', 'regexp', '(.*)'));
            for i = 1:numel(docs)
                jsonStr = jsonencode(docs{i}.document_properties, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
                fid = fopen(fullfile(jsonDocsDir, [docs{i}.id() '.json']), 'w');
                if fid > 0
                    fprintf(fid, '%s', jsonStr);
                    fclose(fid);
                else
                    error('Could not create document JSON file');
                end
            end

            % Write session summary
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
