classdef OldDatasetTest < matlab.unittest.TestCase

    methods (Test)
        function testOldDataset(testCase)
            % Construct path to the dataset
            originalDatasetPath = fullfile(ndi.toolboxdir, 'ndi_common', 'example_datasets', 'oldDataset');

            % Copy to a temporary directory so we don't modify the example
            tempDir = tempname;
            mkdir(tempDir);
            testCase.addTeardown(@rmdir, tempDir, 's');

            [~, datasetName] = fileparts(originalDatasetPath);
            copyfile(originalDatasetPath, tempDir);
            datasetPath = fullfile(tempDir, datasetName);

            % Open the dataset with ndi.dataset.dir (1 input form)
            D = ndi.dataset.dir(datasetPath);

            % Get the session list
            [ref_list, id_list] = D.session_list;

            % Iterate and open sessions
            for i = 1:numel(id_list)
                sessionId = id_list{i};

                S = D.open_session(sessionId);

                % Basic verification that S is a session object
                testCase.verifyTrue(isa(S, 'ndi.session'), 'Returned object should be an ndi.session');
            end
        end
    end
end
