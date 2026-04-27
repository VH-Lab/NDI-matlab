classdef profileTests < matlab.unittest.TestCase
%PROFILETESTS Unit tests for ndi.cloud.profile and a smoke test for the
%ndi.gui.profileEditor.
%
%   Tests run against the in-memory secrets backend so that MATLAB's
%   setSecret/getSecret are never invoked (avoiding any vault-password
%   prompt on the developer's machine). The on-disk profile JSON file
%   IS touched during a run, so its prior contents are snapshotted in
%   TestClassSetup and restored in TestClassTeardown.
%
%   The smoke test for ndi.gui.profileEditor opens the editor, checks
%   the major widgets and the table contents, then deletes the figure
%   so it does not linger after the test run.

    properties
        ProfilesBackup char    % snapshot of on-disk profile JSON
        SecretsBackup  char    % snapshot of AES secrets JSON, if any
    end

    methods (TestClassSetup)
        function backupOnDisk(testCase)
            f = ndi.cloud.profile.filename();
            if isfile(f)
                testCase.ProfilesBackup = fileread(f);
            else
                testCase.ProfilesBackup = '';
            end
            sf = ndi.cloud.profile.getSingleton().SecretsFilename;
            if isfile(sf)
                testCase.SecretsBackup = fileread(sf);
            else
                testCase.SecretsBackup = '';
            end
        end
    end

    methods (TestClassTeardown)
        function restoreOnDisk(testCase)
            f  = ndi.cloud.profile.filename();
            sf = ndi.cloud.profile.getSingleton().SecretsFilename;
            ndi.unittest.cloud.profileTests.writeOrDelete( ...
                f,  testCase.ProfilesBackup);
            ndi.unittest.cloud.profileTests.writeOrDelete( ...
                sf, testCase.SecretsBackup);
            ndi.cloud.profile.reset();
        end
    end

    methods (TestMethodSetup)
        function configureForTest(~)
            ndi.cloud.profile.useBackend('memory');
            ndi.cloud.profile.reset();
        end
    end

    methods (Test)

        function testAddCreatesProfileAndStoresPassword(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            testCase.verifyNotEmpty(uid);
            testCase.verifyClass(uid, 'char');

            list = ndi.cloud.profile.list();
            testCase.assertEqual(numel(list), 1);
            testCase.verifyEqual(list(1).Nickname, 'Lab');
            testCase.verifyEqual(list(1).Email,    'me@lab.org');
            testCase.verifyEqual(list(1).UID,      uid);
            testCase.verifyEqual(list(1).Stage,    'prod');
            testCase.verifyEqual(list(1).PasswordSecret, ['NDI Cloud ' uid]);

            testCase.verifyEqual(ndi.cloud.profile.getPassword(uid), 'pw1');
        end

        function testListReturnsAllProfiles(testCase)
            ndi.cloud.profile.add('A', 'a@x.org', 'p1');
            ndi.cloud.profile.add('B', 'b@x.org', 'p2');
            ndi.cloud.profile.add('C', 'c@x.org', 'p3');
            list = ndi.cloud.profile.list();
            testCase.verifyEqual(numel(list), 3);
            testCase.verifyEqual(sort({list.Nickname}), {'A','B','C'});
        end

        function testGetReturnsProfileByUID(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            p = ndi.cloud.profile.get(uid);
            testCase.verifyEqual(p.Nickname, 'Lab');
            testCase.verifyEqual(p.Email,    'me@lab.org');
            testCase.verifyEqual(p.UID,      uid);
        end

        function testGetUnknownUIDThrows(testCase)
            testCase.verifyError( ...
                @() ndi.cloud.profile.get('NOPE'), ...
                'NDI:cloud:profile:unknownProfile');
        end

        function testRemoveDeletesProfileAndSecret(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            ndi.cloud.profile.remove(uid);
            testCase.verifyEmpty(ndi.cloud.profile.list());
            % Once the profile is gone, the lookup itself fails first.
            testCase.verifyError( ...
                @() ndi.cloud.profile.getPassword(uid), ...
                'NDI:cloud:profile:unknownProfile');
        end

        function testRemoveCurrentClearsCurrentUID(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            ndi.cloud.profile.setCurrent(uid);
            ndi.cloud.profile.remove(uid);
            testCase.verifyEmpty(ndi.cloud.profile.getCurrent());
        end

        function testSetPasswordUpdatesStoredValue(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            ndi.cloud.profile.setPassword(uid, 'pw2');
            testCase.verifyEqual(ndi.cloud.profile.getPassword(uid), 'pw2');
        end

        function testSetCurrentMakesProfileCurrent(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            ndi.cloud.profile.setCurrent(uid);
            cur = ndi.cloud.profile.getCurrent();
            testCase.assertNotEmpty(cur);
            testCase.verifyEqual(cur.UID, uid);
        end

        function testSetCurrentRejectsUnknownUID(testCase)
            testCase.verifyError( ...
                @() ndi.cloud.profile.setCurrent('NOPE'), ...
                'NDI:cloud:profile:unknownProfile');
        end

        function testGetCurrentEmptyWhenNoneSet(testCase)
            ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            testCase.verifyEmpty(ndi.cloud.profile.getCurrent());
        end

        function testStageDefaultsToProd(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            testCase.verifyEqual(ndi.cloud.profile.getStage(uid), 'prod');
        end

        function testSetStageDevAllowed(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            ndi.cloud.profile.setStage(uid, 'dev');
            testCase.verifyEqual(ndi.cloud.profile.getStage(uid), 'dev');
        end

        function testSetStageRejectsInvalidValues(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            testCase.verifyError( ...
                @() ndi.cloud.profile.setStage(uid, 'staging'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testSameEmailAllowedAcrossProfiles(testCase)
            uid1 = ndi.cloud.profile.add('Prod', 'me@lab.org', 'pwA');
            uid2 = ndi.cloud.profile.add('Dev',  'me@lab.org', 'pwB');
            testCase.verifyNotEqual(uid1, uid2);
            testCase.verifyEqual(numel(ndi.cloud.profile.list()), 2);
        end

        function testSwitchProfileSetsEnvVarsAndCurrent(testCase)
            uid = ndi.cloud.profile.add('Lab', 'me@lab.org', 'pw1');
            saved = ndi.unittest.cloud.profileTests.snapshotEnv();
            cleanup = onCleanup(@() ...
                ndi.unittest.cloud.profileTests.restoreEnv(saved)); %#ok<NASGU>

            ndi.cloud.profile.switchProfile(uid);

            testCase.verifyEqual(getenv('CLOUD_API_ENVIRONMENT'), 'prod');
            testCase.verifyEqual(getenv('NDI_CLOUD_USERNAME'),    'me@lab.org');
            testCase.verifyEqual(getenv('NDI_CLOUD_PASSWORD'),    'pw1');

            cur = ndi.cloud.profile.getCurrent();
            testCase.assertNotEmpty(cur);
            testCase.verifyEqual(cur.UID, uid);
        end

        function testSwitchProfileRespectsStage(testCase)
            uid = ndi.cloud.profile.add('Dev', 'me@lab.org', 'pwd');
            ndi.cloud.profile.setStage(uid, 'dev');

            saved = ndi.unittest.cloud.profileTests.snapshotEnv();
            cleanup = onCleanup(@() ...
                ndi.unittest.cloud.profileTests.restoreEnv(saved)); %#ok<NASGU>

            ndi.cloud.profile.switchProfile(uid);
            testCase.verifyEqual(getenv('CLOUD_API_ENVIRONMENT'), 'dev');
        end

        function testFilenameLivesInPrefdir(testCase)
            f = ndi.cloud.profile.filename();
            testCase.verifyClass(f, 'char');
            testCase.verifyTrue(startsWith(f, prefdir), ...
                sprintf('Expected filename to start with prefdir (%s) but got %s', ...
                    prefdir, f));
        end

        function testEditorSmoke(testCase)
            ndi.cloud.profile.add('Sample', 'sample@lab.org', 'pwSmoke');

            fig = ndi.gui.profileEditor();
            cleanup = onCleanup(@() ...
                ndi.unittest.cloud.profileTests.deleteIfValid(fig)); %#ok<NASGU>
            drawnow;

            testCase.assertNotEmpty(fig);
            testCase.verifyTrue(isvalid(fig));
            testCase.verifyClass(fig, 'matlab.ui.Figure');

            tbl = findobj(fig, 'Tag', 'ndiProfileTable');
            testCase.assertNotEmpty(tbl, ...
                'Editor should expose a uitable tagged ndiProfileTable.');
            testCase.verifyEqual(size(tbl.Data, 1), 1);
            testCase.verifyEqual(tbl.Data{1, 2}, 'Sample');
            testCase.verifyEqual(tbl.Data{1, 3}, 'sample@lab.org');

            delete(fig);
            testCase.verifyFalse(isvalid(fig));
        end

    end

    methods (Static, Access = private)

        function deleteIfValid(fig)
            if ~isempty(fig) && isvalid(fig)
                delete(fig);
            end
        end

        function writeOrDelete(filename, content)
            if isempty(content)
                if isfile(filename)
                    delete(filename);
                end
                return;
            end
            fid = fopen(filename, 'w');
            if fid < 0; return; end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, content, 'char');
        end

        function s = snapshotEnv()
            s = struct( ...
                'env',  getenv('CLOUD_API_ENVIRONMENT'), ...
                'user', getenv('NDI_CLOUD_USERNAME'), ...
                'pass', getenv('NDI_CLOUD_PASSWORD'), ...
                'tok',  getenv('NDI_CLOUD_TOKEN'));
        end

        function restoreEnv(s)
            setenv('CLOUD_API_ENVIRONMENT', s.env);
            setenv('NDI_CLOUD_USERNAME',    s.user);
            setenv('NDI_CLOUD_PASSWORD',    s.pass);
            setenv('NDI_CLOUD_TOKEN',       s.tok);
        end

    end
end
