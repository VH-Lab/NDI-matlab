classdef TestDeleteSession < matlab.unittest.TestCase
    properties
        TempPath
        Session
        Dataset
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempPath = fullfile(tempdir, ['ndi_test_session_' num2str(randi(10000))]);
            if isfolder(testCase.TempPath)
                rmdir(testCase.TempPath, 's');
            end
            mkdir(testCase.TempPath);
            testCase.Session = ndi.session.dir('ref', testCase.TempPath);
        end
    end

    methods (TestMethodTeardown)
        function teardownSession(testCase)
             % Clean up dataset if it exists
             if ~isempty(testCase.Dataset)
                 dspath = testCase.Dataset.path;
                 if isfolder(dspath)
                     rmdir(dspath, 's');
                 end
             end

             % Clean up session
             % Note: Session might be deleted by the test, so check.
             if isfolder(testCase.TempPath)
                 rmdir(testCase.TempPath, 's');
             end
        end
    end

    methods (Test)
        function testDeleteNoConfirm(testCase)
            % Test deleteSessionDataStructures(s, false, false) -> Should not delete

            ndi_dir = fullfile(testCase.TempPath, '.ndi');
            testCase.verifyTrue(isfolder(ndi_dir), '.ndi directory should exist initially');

            % deleteSessionDataStructures(areYouSure=false, askUserToConfirm=false)
            testCase.Session.deleteSessionDataStructures(false, false);

            testCase.verifyTrue(isfolder(ndi_dir), 'deleteSessionDataStructures(false, false) should not delete the directory');
        end

        function testDeleteConfirm(testCase)
            % Test deleteSessionDataStructures(s, true, false) -> Should delete

            ndi_dir = fullfile(testCase.TempPath, '.ndi');
            testCase.verifyTrue(isfolder(ndi_dir), '.ndi directory should exist initially');

            % deleteSessionDataStructures(areYouSure=true, askUserToConfirm=false)
            testCase.Session.deleteSessionDataStructures(true, false);

            testCase.verifyFalse(isfolder(ndi_dir), 'deleteSessionDataStructures(true, false) should delete the directory');
        end

        function testIngestedSessionDelete(testCase)
             % Create a dataset
             ds_dirname = tempname;
             mkdir(ds_dirname);
             testCase.Dataset = ndi.dataset.dir('ds_demo', ds_dirname);

             % Add session to dataset as an INGESTED session
             testCase.Dataset.add_ingested_session(testCase.Session);

             % Open the ingested session from the dataset
             session_id = testCase.Session.id();
             session_ingested = testCase.Dataset.open_session(session_id);

             % Verify it thinks it is ingested
             testCase.verifyTrue(session_ingested.isIngestedInDataset(), 'Session should be ingested');

             % Try to delete the ingested session
             try
                 session_ingested.deleteSessionDataStructures(true, false);
                 testCase.verifyFail('deleteSessionDataStructures() did not error on ingested session');
             catch ME
                 testCase.verifyTrue(contains(ME.message, 'Cannot directly delete session that is embedded in dataset'), ...
                     ['Unexpected error message: ' ME.message]);
             end
        end
    end
end
