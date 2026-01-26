classdef testUnlinkSession < matlab.unittest.TestCase
    % TESTUNLINKSESSION - Test the unlink_session method of ndi.dataset

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
        function testUnlinkLinkedSession(testCase)
            % Initialize dataset and session explicitly (Linked)

            % Create session
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

            % Create dataset
            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_demo_unlink', dirname);

            % Link session
            testCase.Dataset.add_linked_session(testCase.Session);

            % Verify it is there
            [refs, ids] = testCase.Dataset.session_list();
            testCase.verifyEqual(numel(ids), 1, 'Session should be linked.');
            testCase.verifyEqual(ids{1}, testCase.Session.id(), 'Session ID should match.');

            % Unlink
            testCase.Dataset.unlink_session(testCase.Session.id(), 'areYouSure', true, 'askUserToConfirm', false);

            % Verify it is gone
            [refs, ids] = testCase.Dataset.session_list();
            testCase.verifyEmpty(ids, 'Session list should be empty after unlink.');

            % Verify files still exist
            p = fullfile(testCase.Session.path, '.ndi');
            testCase.verifyTrue(isfolder(p), 'Session .ndi directory should still exist.');
        end

        function testUnlinkAndDeleteSession(testCase)
            % Create session
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

            % Create dataset
            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_demo_unlink_del', dirname);

            % Link session
            testCase.Dataset.add_linked_session(testCase.Session);

            % Unlink and delete
            testCase.Dataset.unlink_session(testCase.Session.id(), ...
                'areYouSure', true, ...
                'askUserToConfirm', false, ...
                'AlsoDeleteSessionAfterUnlinking', true, ...
                'DeleteSessionAskToConfirm', false);

            % Verify it is gone from dataset
            [refs, ids] = testCase.Dataset.session_list();
            testCase.verifyEmpty(ids, 'Session list should be empty.');

            % Verify files are gone
            p = fullfile(testCase.Session.path, '.ndi');
            testCase.verifyFalse(isfolder(p), 'Session .ndi directory should be deleted.');
        end

        function testUnlinkIngestedSessionError(testCase)
             % Create session
             testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

             % Create dataset
             dirname = tempname;
             mkdir(dirname);
             testCase.Dataset = ndi.dataset.dir('ds_demo_unlink_ingested', dirname);

             % Ingest session
             testCase.Dataset.add_ingested_session(testCase.Session);

             % Try to unlink
             testCase.verifyError(@() testCase.Dataset.unlink_session(testCase.Session.id(), 'areYouSure', true, 'askUserToConfirm', false), ...
                 ?MException);
        end

        function testUnlinkNotConfirmedError(testCase)
            % Create session
            testCase.Session = ndi.unittest.session.buildSession.withDocsAndFiles();

            % Create dataset
            dirname = tempname;
            mkdir(dirname);
            testCase.Dataset = ndi.dataset.dir('ds_demo_unlink_confirm', dirname);

            % Link session
            testCase.Dataset.add_linked_session(testCase.Session);

            % Try to unlink without areYouSure
            testCase.verifyError(@() testCase.Dataset.unlink_session(testCase.Session.id(), 'areYouSure', false, 'askUserToConfirm', false), ...
                 ?MException);
        end
    end
end
