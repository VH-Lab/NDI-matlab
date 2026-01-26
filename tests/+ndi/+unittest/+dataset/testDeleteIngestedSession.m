classdef testDeleteIngestedSession < ndi.unittest.dataset.buildDataset
    % TESTDELETEINGESTEDSESSION - Test the deleteIngestedSession method of ndi.dataset

    methods (Test)
        function testDeleteSuccess(testCase)
            % Verify session exists initially
            [~, id_list] = testCase.Dataset.session_list();
            session_id = testCase.Session.id();
            testCase.verifyTrue(any(strcmp(session_id, id_list)), 'Session ID should be in dataset session list');

            % Verify docs exist
            q = ndi.query('base.session_id', 'exact_string', session_id);
            docs = testCase.Dataset.database_search(q);
            testCase.verifyNotEmpty(docs, 'Session documents should exist');

            % Delete session
            testCase.Dataset.deleteIngestedSession(session_id, 'areYouSure', true, 'askUserToConfirm', false);

            % Verify session is gone
            [~, id_list_after] = testCase.Dataset.session_list();
            testCase.verifyFalse(any(strcmp(session_id, id_list_after)), 'Session ID should NOT be in dataset session list after deletion');

            % Verify docs are gone
            docs_after = testCase.Dataset.database_search(q);
            testCase.verifyEmpty(docs_after, 'Session documents should be gone after deletion');
        end

        function testDeleteNotConfirmed(testCase)
            session_id = testCase.Session.id();

            % Should throw error
            testCase.verifyError(@() testCase.Dataset.deleteIngestedSession(session_id, 'areYouSure', false, 'askUserToConfirm', false), ...
                'ndi:dataset:deleteIngestedSession:notConfirmed');

            % Verify session still exists
             [~, id_list] = testCase.Dataset.session_list();
            testCase.verifyTrue(any(strcmp(session_id, id_list)), 'Session ID should still be in dataset session list');
        end

        function testDeleteLinkedSession(testCase)
            % Create another session to link

            % Use buildSession to get a temporary session
            tempSession = ndi.unittest.session.buildSession.withDocsAndFiles();

            % Link it
            testCase.Dataset.add_linked_session(tempSession);

            % Verify it's there
            [~, id_list] = testCase.Dataset.session_list();
            testCase.verifyTrue(any(strcmp(tempSession.id(), id_list)), 'Linked Session ID should be in dataset session list');

            % Try to delete with deleteIngestedSession - should fail
            testCase.verifyError(@() testCase.Dataset.deleteIngestedSession(tempSession.id(), 'areYouSure', true, 'askUserToConfirm', false), ...
                'ndi:dataset:deleteIngestedSession:isLinked');

            % Cleanup temp session (directories)
            path = tempSession.path;
            if isfolder(path)
                 rmdir(path, 's');
            end
        end

        function testDeleteNonExistentSession(testCase)
            testCase.verifyError(@() testCase.Dataset.deleteIngestedSession('fake_id', 'areYouSure', true, 'askUserToConfirm', false), ...
                'ndi:dataset:deleteIngestedSession:notFound');
        end
    end
end
