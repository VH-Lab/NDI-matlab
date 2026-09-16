classdef OldDatasetTest < matlab.unittest.TestCase

    methods (Test)
        function testOldDataset(testCase)
            % Construct path to the dataset
            originalDatasetPath = fullfile(ndi.toolboxdir, 'ndi_common', 'example_datasets', 'oldDataset');

            % Copy to a temporary directory so we don't modify the example.
            % ndi.dataset.dir runs repairDatasetSessionInfo on a legacy
            % dataset_session_info document during construction, which writes
            % new session_in_a_dataset documents and deletes the old one.
            % Opening originalDatasetPath directly would mutate the shared
            % example. Python's tests/matlab_tests/test_dabrowska.py fixture
            % follows the same copy-before-open pattern for its shared corpus.
            % See ndi-python issue #99.
            tempDir = tempname;
            copyfile(originalDatasetPath, tempDir);
            testCase.addTeardown(@rmdir, tempDir, 's');

            datasetPath = tempDir;

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
