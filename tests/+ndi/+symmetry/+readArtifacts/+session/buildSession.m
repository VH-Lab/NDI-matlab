classdef buildSession < matlab.unittest.TestCase

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testBuildSessionArtifacts(testCase, SourceType)
            % Determine the artifact directory expected from either MATLAB or Python
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'session', 'buildSession', 'testBuildSessionArtifacts');

            % If the directory does not exist, we cannot run the read tests.
            % Return early so the test passes silently instead of showing up as "Incomplete/Filtered"
            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            % Load the NDI session
            % Note: the session reference name might vary; here we use 'exp1' as it is the default in buildSessionSetup
            session = ndi.session.dir('exp1', artifactDir);

            % Read probes.json
            probesJsonFile = fullfile(artifactDir, 'probes.json');
            if ~isfile(probesJsonFile)
                disp(['probes.json file not found in ' SourceType ' artifact directory. Skipping.']);
                return;
            end

            fid = fopen(probesJsonFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);

            expectedProbes = jsondecode(rawJson);

            % Get actual probes from session
            actualProbes = session.getprobes();

            % Verify probe count matches
            testCase.verifyEqual(numel(actualProbes), numel(expectedProbes), ['Number of actual probes does not match ' SourceType ' generated artifacts.']);

            % Sort and compare expected vs actual if counts match
            if numel(actualProbes) == numel(expectedProbes)
                for i = 1:numel(expectedProbes)
                    % Match based on properties since order might not be guaranteed
                    expected = expectedProbes(i);
                    found = false;
                    for j = 1:numel(actualProbes)
                        actual = actualProbes{j};
                        if strcmp(expected.name, actual.name) && expected.reference == actual.reference && strcmp(expected.type, actual.type)
                            found = true;
                            testCase.verifyEqual(actual.subject_id, expected.subject_id, ['Subject ID mismatch for probe ', expected.name, ' in ', SourceType]);
                            break;
                        end
                    end
                    testCase.verifyTrue(found, ['Probe from ', SourceType, ' artifact not found in MATLAB session: ', expected.name]);
                end
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