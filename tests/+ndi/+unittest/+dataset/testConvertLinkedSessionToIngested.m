classdef testConvertLinkedSessionToIngested < matlab.unittest.TestCase
    % TESTCONVERTLINKEDSESSIONTOINGESTED - Test the convertLinkedSessionToIngested method of ndi.dataset

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
        function testConvertLinkedToIngested(testCase)
            % Create session with docs and files
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();
            session_id = testCase.Session.id();

            % Create dataset and link the session
            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_convert', dirname);
            testCase.Dataset.add_linked_session(testCase.Session);

            % Verify session is linked
            [~, ids] = testCase.Dataset.session_list();
            testCase.verifyEqual(numel(ids), 1, 'Should have one session.');

            % Verify it is not yet ingested in dataset
            S = testCase.Dataset.open_session(session_id);
            testCase.verifyFalse(S.isIngestedInDataset(), ...
                'Linked session should not report as ingested in dataset.');

            % Convert linked to ingested
            testCase.Dataset.convertLinkedSessionToIngested(session_id, ...
                'areYouSure', true, 'askUserToConfirm', false);

            % Verify session is still in the dataset
            [~, ids] = testCase.Dataset.session_list();
            testCase.verifyEqual(numel(ids), 1, 'Should still have one session.');
            testCase.verifyEqual(ids{1}, session_id, 'Session ID should match.');

            % Verify it is now ingested in dataset
            S_ingested = testCase.Dataset.open_session(session_id);
            testCase.verifyTrue(S_ingested.isIngestedInDataset(), ...
                'Converted session should report as ingested in dataset.');

            % Verify documents are accessible from the dataset
            q = ndi.query('base.session_id', 'exact_string', session_id);
            docs = testCase.Dataset.database_search(q);
            testCase.verifyGreaterThan(numel(docs), 0, ...
                'Should find documents for the ingested session.');
        end

        function testConvertAlreadyIngestedErrors(testCase)
            % Create session and ingest it directly
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_convert_err', dirname);
            testCase.Dataset.add_ingested_session(testCase.Session);

            % Try to convert - should error because it's already ingested
            testCase.verifyError(@() testCase.Dataset.convertLinkedSessionToIngested( ...
                testCase.Session.id(), 'areYouSure', true, 'askUserToConfirm', false), ...
                ?MException);
        end

        function testConvertNotConfirmedErrors(testCase)
            % Create session and link it
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_convert_noconfirm', dirname);
            testCase.Dataset.add_linked_session(testCase.Session);

            % Try to convert without confirmation - should error
            testCase.verifyError(@() testCase.Dataset.convertLinkedSessionToIngested( ...
                testCase.Session.id(), 'areYouSure', false, 'askUserToConfirm', false), ...
                ?MException);
        end

        function testConvertNotFoundErrors(testCase)
            % Create dataset with no sessions
            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_convert_notfound', dirname);
            testCase.Session = [];

            % Try to convert a non-existent session
            testCase.verifyError(@() testCase.Dataset.convertLinkedSessionToIngested( ...
                'nonexistent_id', 'areYouSure', true, 'askUserToConfirm', false), ...
                ?MException);
        end
    end
end
