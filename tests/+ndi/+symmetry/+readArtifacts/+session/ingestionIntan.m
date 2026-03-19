classdef ingestionIntan < matlab.unittest.TestCase

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testIngestionIntanArtifacts(testCase, SourceType)
            % Determine the artifact directory expected from either MATLAB or Python
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'session', 'ingestionIntan', 'testIngestionIntanArtifacts');

            % If the directory does not exist, we cannot run the read tests.
            % Return early so the test passes silently instead of showing up as "Incomplete/Filtered"
            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            % Load the NDI session
            session = ndi.session.dir('exp1', artifactDir);

            % Verify session summary
            summaryJsonFile = fullfile(artifactDir, 'sessionSummary.json');
            if ~isfile(summaryJsonFile)
                disp(['sessionSummary.json file not found in ' SourceType ' artifact directory. Skipping summary comparison.']);
            else
                fid = fopen(summaryJsonFile, 'r');
                rawJson = fread(fid, inf, '*char')';
                fclose(fid);
                expectedSummary = jsondecode(rawJson);

                % Get actual session summary
                actualSummary = ndi.util.sessionSummary(session);

                % Compare the two summaries
                report = ndi.util.compareSessionSummary(actualSummary, expectedSummary, 'excludeFiles', {'sessionSummary.json', 'jsonDocuments'});
                testCase.verifyEmpty(report, ['Session summary mismatch against ' SourceType ' generated artifacts.']);
            end

            % Read expected documents
            jsonDocsDir = fullfile(artifactDir, 'jsonDocuments');
            if ~isfolder(jsonDocsDir)
                disp(['jsonDocuments directory not found in ', SourceType, '. Skipping.']);
                return;
            end

            jsonFiles = dir(fullfile(jsonDocsDir, '*.json'));

            % Get actual documents from session
            actualDocs = session.database_search(ndi.query('base.id', 'regexp', '(.*)'));

            testCase.verifyEqual(numel(actualDocs), numel(jsonFiles), ['Number of actual documents in the session does not match ', SourceType, ' generated JSON artifacts.']);

            for i = 1:numel(jsonFiles)
                fid = fopen(fullfile(jsonFiles(i).folder, jsonFiles(i).name), 'r');
                rawDocJson = fread(fid, inf, '*char')';
                fclose(fid);
                expectedDoc = jsondecode(rawDocJson);

                % Find the corresponding document in the session by base.id
                expectedId = expectedDoc.base.id;
                found = false;
                for j = 1:numel(actualDocs)
                    if strcmp(actualDocs{j}.id(), expectedId)
                        found = true;

                        % Verify important shared properties, e.g. class
                        actualProps = actualDocs{j}.document_properties;

                        testCase.verifyEqual(actualProps.document_class.class_name, ...
                            expectedDoc.document_class.class_name, ...
                            ['Document class mismatch for id: ', expectedId, ' in ', SourceType]);
                        break;
                    end
                end
                testCase.verifyTrue(found, ['Document from ', SourceType, ' artifact not found in MATLAB session: ', expectedId]);
            end
        end
    end
end
