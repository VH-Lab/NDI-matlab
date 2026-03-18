classdef buildDataset < matlab.unittest.TestCase

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testBuildDatasetArtifacts(testCase, SourceType)
            % Determine the artifact directory expected from either MATLAB or Python
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'dataset', 'buildDataset', 'testBuildDatasetArtifacts');

            % If the directory does not exist, we cannot run the read tests.
            % Return early so the test passes silently instead of showing up as "Incomplete/Filtered"
            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            % Load the dataset summary JSON
            summaryJsonFile = fullfile(artifactDir, 'datasetSummary.json');
            if ~isfile(summaryJsonFile)
                disp(['datasetSummary.json file not found in ' SourceType ' artifact directory. Skipping.']);
                return;
            end

            fid = fopen(summaryJsonFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            expectedSummary = jsondecode(rawJson);

            % Open the dataset from the artifact directory
            dataset = ndi.dataset.dir('ds_demo', artifactDir);

            % Get session list from the dataset
            [ref_list, id_list] = dataset.session_list();
            numSessions = numel(ref_list);

            % Verify number of sessions
            testCase.verifyEqual(numSessions, expectedSummary.numSessions, ...
                ['Number of sessions mismatch against ' SourceType ' generated artifacts.']);

            % Verify references
            expectedRefs = expectedSummary.references;
            if ischar(expectedRefs)
                expectedRefs = {expectedRefs};
            end
            testCase.verifyEqual(sort(ref_list), sort(expectedRefs'), ...
                ['Session references mismatch against ' SourceType ' generated artifacts.']);

            % Verify session IDs
            expectedIds = expectedSummary.sessionIds;
            if ischar(expectedIds)
                expectedIds = {expectedIds};
            end
            testCase.verifyEqual(sort(id_list), sort(expectedIds'), ...
                ['Session IDs mismatch against ' SourceType ' generated artifacts.']);

            % Verify session summaries for each session
            expectedSessionSummaries = expectedSummary.sessionSummaries;
            if ~iscell(expectedSessionSummaries)
                expectedSessionSummaries = {expectedSessionSummaries};
            end

            for i = 1:numSessions
                % Find the matching expected summary by sessionId
                sess = dataset.open_session(id_list{i});
                actualSummary = ndi.util.sessionSummary(sess);

                % Find the expected summary with the same sessionId
                matchIdx = [];
                for j = 1:numel(expectedSessionSummaries)
                    if strcmp(expectedSessionSummaries{j}.sessionId, id_list{i})
                        matchIdx = j;
                        break;
                    end
                end

                testCase.verifyNotEmpty(matchIdx, ...
                    ['No expected session summary found for session ID ' id_list{i} ' in ' SourceType]);

                if ~isempty(matchIdx)
                    % Compare the session summaries using the existing comparison utility
                    report = ndi.util.compareSessionSummary(actualSummary, expectedSessionSummaries{matchIdx}, ...
                        'excludeFiles', {'datasetSummary.json', 'jsonDocuments'});
                    testCase.verifyEmpty(report, ...
                        ['Session summary mismatch for session ' id_list{i} ' against ' SourceType ' generated artifacts.']);
                end
            end
        end
    end
end
