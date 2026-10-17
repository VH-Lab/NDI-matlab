classdef TestFindCommand < matlab.unittest.TestCase
    % TestFindCommand - where ndi.python.findCommand looks, and in what order.
    %
    % Hermetic: HOME / USERPROFILE and NDI_PYTHON_BIN point into a temp
    % folder holding dummy files, the viewer preferences are emptied for
    % the test and restored after, and most tests use a command name no
    % real machine has, so neither /usr/local/bin nor the login shell can
    % answer. Nothing is downloaded or installed.

    properties
        Root        % temp folder for this test
        Home        % fake user home inside Root
        Name        % a command name nothing else provides
        SavedPrefs  % preference values to restore
    end

    properties (Constant)
        PrefPaths = {'GUI.GEFManager.ViewerLauncher', ...
            'GUI.LightsheetZarrManager.ViewerLauncher'}
    end

    methods (TestMethodSetup)
        function makeFakeHome(testCase)
            % The fixtures restore these variables after each test, so the
            % tests themselves may setenv freely.
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            testCase.Home = fullfile(testCase.Root, 'home');
            mkdir(testCase.Home);
            testCase.applyFixture(EnvironmentVariableFixture('HOME', testCase.Home));
            testCase.applyFixture(EnvironmentVariableFixture('USERPROFILE', testCase.Home));
            testCase.applyFixture(EnvironmentVariableFixture('NDI_PYTHON_BIN', ''));
            testCase.Name = sprintf('ndiFakeTool%d', randi(1e9));

            testCase.SavedPrefs = cell(size(testCase.PrefPaths));
            for i = 1:numel(testCase.PrefPaths)
                testCase.SavedPrefs{i} = ndi.preferences.get(testCase.PrefPaths{i});
                ndi.preferences.set(testCase.PrefPaths{i}, "");
            end
            testCase.addTeardown(@() testCase.restorePrefs());

            ndi.python.clearCommandCache();
            testCase.addTeardown(@() ndi.python.clearCommandCache());
        end
    end

    methods (Access = private)
        function restorePrefs(testCase)
            for i = 1:numel(testCase.PrefPaths)
                try
                    ndi.preferences.set(testCase.PrefPaths{i}, testCase.SavedPrefs{i});
                catch
                end
            end
        end

        function f = touch(testCase, folder, fileName)
            % A dummy "executable": findCommand only checks that it exists.
            if ~isfolder(folder)
                mkdir(folder);
            end
            f = fullfile(folder, fileName);
            fid = fopen(f, 'w');
            testCase.assertGreaterThan(fid, 0);
            fprintf(fid, '#!/bin/sh\n');
            fclose(fid);
        end

        function d = folder(testCase, varargin)
            d = fullfile(testCase.Root, varargin{:});
        end
    end

    methods (Test)

        function testFindsTheInstallerFolder(testCase)
            want = testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), testCase.Name);
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), want);
        end

        function testNdiHomeIsUnderTheUserHome(testCase)
            testCase.verifyEqual(ndi.python.ndiHome(), fullfile(testCase.Home, '.ndi'));
        end

        function testFindsUvToolInstallFolder(testCase)
            want = testCase.touch(fullfile(testCase.Home, '.local', 'bin'), testCase.Name);
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), want);
        end

        function testNdiHomeBeatsLocalBin(testCase)
            testCase.touch(fullfile(testCase.Home, '.local', 'bin'), testCase.Name);
            want = testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), testCase.Name);
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), want);
        end

        function testEnvironmentVariableBeatsNdiHome(testCase)
            testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), testCase.Name);
            envDir = testCase.folder('envbin');
            want = testCase.touch(envDir, testCase.Name);
            setenv('NDI_PYTHON_BIN', envDir);
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), want);
        end

        function testEnvironmentVariableMayListSeveralFolders(testCase)
            first = testCase.folder('empty');
            mkdir(first);
            second = testCase.folder('second');
            want = testCase.touch(second, testCase.Name);
            setenv('NDI_PYTHON_BIN', ...
                [first pathsep second]);
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), want);
        end

        function testPreferenceBeatsEverything(testCase)
            envDir = testCase.folder('envbin');
            testCase.touch(envDir, 'napariViewGEF');
            setenv('NDI_PYTHON_BIN', envDir);
            chosen = testCase.touch(testCase.folder('mine'), 'myViewer');
            ndi.preferences.set('GUI.GEFManager.ViewerLauncher', string(chosen));
            testCase.verifyEqual(ndi.python.findCommand('napariViewGEF'), chosen);
        end

        function testLightsheetHasItsOwnPreference(testCase)
            chosen = testCase.touch(testCase.folder('mine'), 'myLightsheet');
            ndi.preferences.set('GUI.LightsheetZarrManager.ViewerLauncher', string(chosen));
            testCase.verifyEqual(ndi.python.findCommand('napariViewLightsheet'), chosen);
        end

        function testAPreferenceForAMissingFileIsSkipped(testCase)
            envDir = testCase.folder('envbin');
            want = testCase.touch(envDir, 'napariViewGEF');
            setenv('NDI_PYTHON_BIN', envDir);
            ndi.preferences.set('GUI.GEFManager.ViewerLauncher', ...
                string(testCase.folder('nothere', 'napariViewGEF')));
            testCase.verifyEqual(ndi.python.findCommand('napariViewGEF'), want);
        end

        function testTheLegacyDefaultIsNotAnExplicitChoice(testCase)
            % The old default was saved into everyone's preferences file;
            % it must not shadow a fresh ndi.python.install().
            envDir = testCase.folder('envbin');
            want = testCase.touch(envDir, 'napariViewGEF');
            setenv('NDI_PYTHON_BIN', envDir);
            ndi.preferences.set('GUI.GEFManager.ViewerLauncher', ...
                "/usr/local/bin/napariViewGEF");
            testCase.verifyEqual(ndi.python.findCommand('napariViewGEF'), want);
        end

        function testResultIsCachedUntilCleared(testCase)
            first = testCase.touch(testCase.folder('a'), testCase.Name);
            setenv('NDI_PYTHON_BIN', ...
                testCase.folder('a'));
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), first);

            second = testCase.touch(testCase.folder('b'), testCase.Name);
            setenv('NDI_PYTHON_BIN', ...
                testCase.folder('b'));
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), first, ...
                'a found path is remembered for the session');
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name, 'Refresh', true), ...
                second, 'Refresh searches again');

            setenv('NDI_PYTHON_BIN', ...
                testCase.folder('a'));
            ndi.python.findCommand('clear');
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), first);
            setenv('NDI_PYTHON_BIN', ...
                testCase.folder('b'));
            ndi.python.clearCommandCache();
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), second);
        end

        function testACachedPathThatVanishedIsSearchedAgain(testCase)
            gone = testCase.touch(testCase.folder('a'), testCase.Name);
            want = testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), testCase.Name);
            setenv('NDI_PYTHON_BIN', ...
                testCase.folder('a'));
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), gone);
            delete(gone);
            testCase.verifyEqual(ndi.python.findCommand(testCase.Name), want);
        end

        function testWindowsLooksForExe(testCase)
            want = testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), ...
                [testCase.Name '.exe']);
            testCase.verifyEqual( ...
                ndi.python.findCommand(testCase.Name, 'IsWindows', true), want);
        end

        function testWindowsIgnoresAFileWithoutExe(testCase)
            testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), testCase.Name);
            testCase.verifyError( ...
                @() ndi.python.findCommand(testCase.Name, 'IsWindows', true), ...
                'ndi:python:commandNotFound');
        end

        function testPosixDoesNotAppendExe(testCase)
            testCase.assumeFalse(ispc, 'POSIX naming.');
            testCase.touch(fullfile(testCase.Home, '.ndi', 'bin'), [testCase.Name '.exe']);
            testCase.verifyError( ...
                @() ndi.python.findCommand(testCase.Name, 'IsWindows', false), ...
                'ndi:python:commandNotFound');
        end

        function testNotFoundNamesTheInstaller(testCase)
            try
                ndi.python.findCommand(testCase.Name);
                testCase.verifyFail('findCommand should have raised.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'ndi:python:commandNotFound');
                testCase.verifySubstring(ME.message, 'ndi.python.install()');
                testCase.verifySubstring(ME.message, testCase.Name);
            end
        end

        function testFindsThroughTheLoginShell(testCase)
            % Last resort: whatever the user's shell would run.
            testCase.assumeFalse(ispc, 'Uses /bin/sh.');
            p = ndi.python.findCommand('sh');
            testCase.verifyTrue(isfile(p), p);
            [~, name] = fileparts(p);
            testCase.verifyEqual(name, 'sh');
        end

        function testUnsafeNamesAreRefusedBeforeAnyShell(testCase)
            bad = {'a b', 'x;rm', '../ndi', 'ndi.exe', '$(id)', 'a''b'};
            for i = 1:numel(bad)
                testCase.verifyError(@() ndi.python.findCommand(bad{i}), ...
                    'ndi:python:invalidCommandName', bad{i});
            end
        end
    end
end
