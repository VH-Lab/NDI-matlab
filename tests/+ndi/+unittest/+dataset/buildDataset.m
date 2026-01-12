classdef buildDataset < matlab.unittest.TestCase
    properties
        Dataset
        Session
    end

    methods (TestMethodSetup)
        function setupDataset(testCase)
            [testCase.Dataset, testCase.Session] = ndi.unittest.dataset.buildDataset.sessionWithIngestedDocsAndFiles();
        end
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

    methods (Static)
        function [dataset, session] = sessionWithIngestedDocsAndFiles()
             % Create session
             session = ndi.unittest.session.buildSession.withDocsAndFiles();

             % Create dataset
             dirname = tempname;
             mkdir(dirname);
             dataset = ndi.dataset.dir('ds_demo', dirname);

             % Add session to dataset
             dataset.add_ingested_session(session);
        end
    end
end
