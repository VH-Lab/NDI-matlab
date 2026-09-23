classdef sessiontableMigrationTests < matlab.unittest.TestCase
%SESSIONTABLEMIGRATIONTESTS Cover ndi.session.sessiontable's one-time
% ~/.ndi/ migration.
%
%   The migration copies fullfile(userpath, 'Preferences', 'NDI',
%   'local_sessiontable.txt') (and its _bkup* siblings) into
%   ~/.ndi/local_sessiontable.txt when the new location has nothing.
%   These tests exercise every branch by staging files at both
%   locations and calling migrateLegacyIfNeeded directly. Any files
%   that already exist at those two paths (a real developer's saved
%   sessiontable) are snapshotted in TestClassSetup and restored in
%   TestClassTeardown, matching the pattern in profileTests.

    properties
        NewFileBackup      char
        LegacyFileBackup   char
        NewBackupSnapshots struct  % .name, .content pairs for _bkup* in new dir
        LegacyBackupSnapshots struct
        StagedNewFiles     cell  % anything we wrote that wasn't there before
        StagedLegacyFiles  cell
    end

    methods (TestClassSetup)
        function snapshotOnDisk(testCase)
            testCase.NewFileBackup     = testCase.readFileOrEmpty( ...
                ndi.session.sessiontable.localtablefilename());
            testCase.LegacyFileBackup  = testCase.readFileOrEmpty( ...
                ndi.session.sessiontable.legacylocaltablefilename());
            testCase.NewBackupSnapshots    = testCase.snapshotBackups( ...
                fileparts(ndi.session.sessiontable.localtablefilename()));
            testCase.LegacyBackupSnapshots = testCase.snapshotBackups( ...
                fileparts(ndi.session.sessiontable.legacylocaltablefilename()));
            testCase.StagedNewFiles     = {};
            testCase.StagedLegacyFiles  = {};
        end
    end

    methods (TestClassTeardown)
        function restoreOnDisk(testCase)
            % Wipe anything we staged (both locations).
            for i = 1:numel(testCase.StagedNewFiles)
                if isfile(testCase.StagedNewFiles{i})
                    delete(testCase.StagedNewFiles{i});
                end
            end
            for i = 1:numel(testCase.StagedLegacyFiles)
                if isfile(testCase.StagedLegacyFiles{i})
                    delete(testCase.StagedLegacyFiles{i});
                end
            end
            % Restore what was there before.
            testCase.writeOrDelete( ...
                ndi.session.sessiontable.localtablefilename(), ...
                testCase.NewFileBackup);
            testCase.writeOrDelete( ...
                ndi.session.sessiontable.legacylocaltablefilename(), ...
                testCase.LegacyFileBackup);
            testCase.restoreBackups( ...
                fileparts(ndi.session.sessiontable.localtablefilename()), ...
                testCase.NewBackupSnapshots);
            testCase.restoreBackups( ...
                fileparts(ndi.session.sessiontable.legacylocaltablefilename()), ...
                testCase.LegacyBackupSnapshots);
        end
    end

    methods (TestMethodSetup)
        function clearBothLocations(testCase)
            % Every test starts with a clean slate: no file at either
            % location. Anything the test writes lands in the tracked
            % Staged* lists so teardown can remove it before restoring
            % the class-level snapshots.
            testCase.deleteIfExists( ...
                ndi.session.sessiontable.localtablefilename());
            testCase.deleteIfExists( ...
                ndi.session.sessiontable.legacylocaltablefilename());
        end
    end

    methods (Test)

        function testPathConstantsPreferencesIsNdiUserPrefDir(testCase)
            % Both cross-language stores now share ~/.ndi/. This test
            % pins the PathConstants change so it does not silently
            % regress on a merge that reintroduces prefdir/userpath.
            expected = fullfile( ...
                char(java.lang.System.getProperty('user.home')), '.ndi');
            testCase.verifyEqual(ndi.common.PathConstants.Preferences, ...
                expected);
        end

        function testLocalTableFilenameLandsUnderPreferences(testCase)
            f = ndi.session.sessiontable.localtablefilename();
            testCase.verifyTrue(startsWith(f, ...
                ndi.common.PathConstants.Preferences));
            testCase.verifyEqual(char(strtrim(string(f))), ...
                fullfile(ndi.common.PathConstants.Preferences, ...
                         'local_sessiontable.txt'));
        end

        function testMigrationCopiesLegacyTable(testCase)
            legacy = ndi.session.sessiontable.legacylocaltablefilename();
            testCase.stageLegacyFile(legacy, ...
                sprintf('session_id\tpath\nabc\t/data/one\n'));

            ndi.session.sessiontable.migrateLegacyIfNeeded();

            new = ndi.session.sessiontable.localtablefilename();
            testCase.trackNewFile(new);
            testCase.verifyTrue(isfile(new), ...
                'migration should have written the new file');
            testCase.verifyEqual(fileread(new), fileread(legacy));
            testCase.verifyTrue(isfile(legacy), ...
                'legacy file should remain in place for downgrade');
        end

        function testMigrationAlsoCopiesBackupSiblings(testCase)
            legacy = ndi.session.sessiontable.legacylocaltablefilename();
            testCase.stageLegacyFile(legacy, ...
                sprintf('session_id\tpath\nabc\t/data/one\n'));
            legacyDir = fileparts(legacy);
            b1 = fullfile(legacyDir, 'local_sessiontable_bkup001.txt');
            b2 = fullfile(legacyDir, 'local_sessiontable_bkup002.txt');
            testCase.stageLegacyFile(b1, 'old-1');
            testCase.stageLegacyFile(b2, 'old-2');

            ndi.session.sessiontable.migrateLegacyIfNeeded();

            newDir = fileparts(ndi.session.sessiontable.localtablefilename());
            newB1 = fullfile(newDir, 'local_sessiontable_bkup001.txt');
            newB2 = fullfile(newDir, 'local_sessiontable_bkup002.txt');
            testCase.trackNewFile(ndi.session.sessiontable.localtablefilename());
            testCase.trackNewFile(newB1);
            testCase.trackNewFile(newB2);
            testCase.verifyEqual(fileread(newB1), 'old-1');
            testCase.verifyEqual(fileread(newB2), 'old-2');
        end

        function testMigrationIsNoOpWhenNewFileAlreadyExists(testCase)
            new = ndi.session.sessiontable.localtablefilename();
            testCase.stageNewFile(new, ...
                sprintf('session_id\tpath\nkeep\t/data/keep\n'));
            legacy = ndi.session.sessiontable.legacylocaltablefilename();
            testCase.stageLegacyFile(legacy, ...
                sprintf('session_id\tpath\nshould_not_win\t/data/nope\n'));

            ndi.session.sessiontable.migrateLegacyIfNeeded();

            testCase.verifyEqual(fileread(new), ...
                sprintf('session_id\tpath\nkeep\t/data/keep\n'), ...
                'migration must not overwrite the new-location file');
        end

        function testMigrationNoOpWhenNoLegacyPresent(testCase)
            % Deliberately no staging: both locations are empty.
            ndi.session.sessiontable.migrateLegacyIfNeeded();
            testCase.verifyFalse(isfile( ...
                ndi.session.sessiontable.localtablefilename()));
        end

        function testGetSessionTableTriggersMigration(testCase)
            % Full end-to-end: getsessiontable() calls the migration
            % first, so a fresh sessiontable() instance sees the
            % legacy content on first read.
            legacy = ndi.session.sessiontable.legacylocaltablefilename();
            testCase.stageLegacyFile(legacy, ...
                sprintf('session_id\tpath\nabc\t/data/one\n'));

            st = ndi.session.sessiontable();
            t = st.getsessiontable();
            testCase.trackNewFile( ...
                ndi.session.sessiontable.localtablefilename());
            testCase.assertEqual(numel(t), 1);
            testCase.verifyEqual(t(1).session_id, 'abc');
            testCase.verifyEqual(t(1).path, '/data/one');
        end

    end

    methods (Access = private)

        function stageLegacyFile(testCase, path, body)
            testCase.ensureDir(fileparts(path));
            testCase.writeFile(path, body);
            testCase.StagedLegacyFiles{end+1} = path;
        end

        function stageNewFile(testCase, path, body)
            testCase.ensureDir(fileparts(path));
            testCase.writeFile(path, body);
            testCase.StagedNewFiles{end+1} = path;
        end

        function trackNewFile(testCase, path)
            testCase.StagedNewFiles{end+1} = path;
        end

    end

    methods (Static, Access = private)

        function s = readFileOrEmpty(path)
            if isfile(path)
                s = fileread(path);
            else
                s = '';
            end
        end

        function writeOrDelete(path, content)
            if isempty(content)
                if isfile(path)
                    delete(path);
                end
                return;
            end
            fid = fopen(path, 'w');
            if fid < 0; return; end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, content, 'char');
        end

        function deleteIfExists(path)
            if isfile(path)
                delete(path);
            end
            % Also clear any backup siblings so tests are isolated.
            parent = fileparts(path);
            if isfolder(parent)
                d = dir(fullfile(parent, 'local_sessiontable_bkup*.txt'));
                for i = 1:numel(d)
                    delete(fullfile(parent, d(i).name));
                end
            end
        end

        function ensureDir(path)
            if ~isfolder(path)
                mkdir(path);
            end
        end

        function writeFile(path, body)
            fid = fopen(path, 'w');
            if fid < 0
                error('sessiontableMigrationTests:writeFailed', ...
                    'Could not open %s for writing', path);
            end
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, body, 'char');
        end

        function s = snapshotBackups(dirPath)
            s = struct('name', {}, 'content', {});
            if ~isfolder(dirPath); return; end
            d = dir(fullfile(dirPath, 'local_sessiontable_bkup*.txt'));
            for i = 1:numel(d)
                s(end+1).name = d(i).name; %#ok<AGROW>
                s(end).content = fileread(fullfile(dirPath, d(i).name));
            end
        end

        function restoreBackups(dirPath, snap)
            if isempty(snap); return; end
            if ~isfolder(dirPath); mkdir(dirPath); end
            for i = 1:numel(snap)
                fid = fopen(fullfile(dirPath, snap(i).name), 'w');
                if fid < 0; continue; end
                cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fwrite(fid, snap(i).content, 'char');
                clear cleaner;
            end
        end

    end
end
