classdef testIsIngestedInDataset < matlab.unittest.TestCase
    % TESTISINGESTEDINDATASET - Test the isIngestedInDataset method of ndi.session

    properties
        Dataset
        Session
    end

    methods (TestMethodTeardown)
        function teardownDataset(testCase)
             % Clean up
             if ~isempty(testCase.Dataset)
                 path = testCase.Dataset.path;
                 if isfolder(path)
                     rmdir(path, 's');
                 end
             end
             if ~isempty(testCase.Session)
                 path = testCase.Session.path;
                 if isfolder(path)
                     rmdir(path, 's');
                 end
             end
        end
    end

    methods (Test)
        function testIsIngestedInDatasetLogic(testCase)
            % 1. Create a session (standalone)
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

            % Verify isIngestedInDataset is false for a standalone session
            testCase.verifyFalse(testCase.Session.isIngestedInDataset(), ...
                'Standalone session should not be considered ingested in a dataset.');

            % 2. Create a dataset
            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_demo', dirname);

            % 3. Add session to dataset as an INGESTED session
            testCase.Dataset.add_ingested_session(testCase.Session);

            % 4. Open the ingested session from the dataset
            session_id = testCase.Session.id();
            session_ingested = testCase.Dataset.open_session(session_id);

            % Verify isIngestedInDataset returns TRUE for the ingested session object
            testCase.verifyTrue(session_ingested.isIngestedInDataset(), ...
                'Session opened from dataset (ingested) should return true.');
        end
    end
end
