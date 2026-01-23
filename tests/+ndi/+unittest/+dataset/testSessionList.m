classdef testSessionList < matlab.unittest.TestCase
    % TESTSESSIONLIST - Test the session_list method of ndi.dataset

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
        function testSessionListOutputs(testCase)
            % Initialize dataset and session explicitly
            [testCase.Dataset, testCase.Session] = ndi.unittest.dataset.buildDataset.sessionWithIngestedDocsAndFiles();

            % Execute the method under test
            [refs, sess, sess_docs, dset_doc] = testCase.Dataset.session_list();

            % Verify outputs

            % 1. Verify refs
            testCase.verifyEqual(refs, {'exp_demo'}, 'Session reference should match expected value.');

            % 2. Verify sess (Session IDs)
            testCase.verifyEqual(sess, {testCase.Session.id()}, 'Session ID should match the ingested session ID.');

            % 3. Verify sess_docs (Session in a dataset document IDs)
            testCase.verifyTrue(iscell(sess_docs) && numel(sess_docs) == 1, 'sess_docs should be a cell array of size 1.');
            session_doc_id = sess_docs{1};

            % Search for the document corresponding to sess_docs{1}
            L = testCase.Dataset.database_search(ndi.query('base.id', 'exact_string', session_doc_id));
            testCase.verifyEqual(numel(L), 1, 'Should find exactly one document for the session_in_a_dataset ID.');

            doc = L{1};

            % Verify document properties as requested
            % check that sess matches the session_id values in the L{i} documents
            testCase.verifyEqual(doc.document_properties.session_in_a_dataset.session_id, sess{1}, ...
                'The session_in_a_dataset document should have the correct session_id.');

            % check that sess_docs matches the L{i}.document_properties.base.id (implicitly done by search, but verify explicit property)
            testCase.verifyEqual(doc.document_properties.base.id, sess_docs{1}, ...
                 'The document ID should match the search ID.');

            % Verify other fields in session_in_a_dataset
            testCase.verifyEqual(doc.document_properties.session_in_a_dataset.session_reference, refs{1}, ...
                'The session_reference should match.');
            testCase.verifyEqual(doc.document_properties.session_in_a_dataset.session_creator, 'ndi.session.dir', ...
                'The session_creator should be ndi.session.dir.');

            % 4. Verify dset_doc (Dataset's own session document ID)
            % It should be a single string
            testCase.verifyTrue(ischar(dset_doc) || (isstring(dset_doc) && isscalar(dset_doc)), 'dset_doc should be a string.');

            % Verify it corresponds to the dataset's own session
            q_dset_session = ndi.query('base.id', 'exact_string', dset_doc);
            L_dset = testCase.Dataset.database_search(q_dset_session);
            testCase.verifyEqual(numel(L_dset), 1, 'Should find exactly one document for the dataset session ID.');

            dset_session_doc = L_dset{1};
            testCase.verifyEqual(dset_session_doc.document_properties.base.session_id, testCase.Dataset.id(), ...
                'The dataset session document should belong to the dataset (base.session_id == dataset.id).');
            testCase.verifyTrue(ndi.document(dset_session_doc).isa('session'), ...
                'The dataset session document should be of type "session".');

        end
    end
end
