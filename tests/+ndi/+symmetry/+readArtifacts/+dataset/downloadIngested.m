classdef downloadIngested < matlab.unittest.TestCase

    properties (TestParameter)
        % Define the two potential sources of artifacts
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testDownloadIngestedArtifacts(testCase, SourceType)
            % Determine the artifact directory expected from either MATLAB or Python
            artifactDir = fullfile(tempdir(), 'NDI', 'symmetryTest', SourceType, 'dataset', 'downloadIngested', 'testDownloadIngestedArtifacts');

            % If the directory does not exist, skip gracefully
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

            % The downloaded dataset lives inside the artifact directory
            datasetPath = fullfile(artifactDir, '69a8705aa9ab25373cdc6563');
            testCase.verifyTrue(isfolder(datasetPath), ...
                ['Expected dataset directory not found in ' SourceType ' artifacts.']);

            % Open the dataset from the artifact directory
            dataset = ndi.dataset.dir(datasetPath);

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
                % Open the session and create actual summary
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

            % Verify document counts match for each session
            if isfield(expectedSummary, 'documentCounts')
                for i = 1:numSessions
                    sess = dataset.open_session(id_list{i});
                    docs = sess.database_search(ndi.query('base.id', 'regexp', '(.*)'));
                    actualDocCount = numel(docs);

                    expectedDocCount = expectedSummary.documentCounts.(id_list{i});

                    testCase.verifyEqual(actualDocCount, expectedDocCount, ...
                        ['Document count mismatch for session ' id_list{i} ' against ' SourceType ' generated artifacts.']);
                end
            end
        end
    end
end
