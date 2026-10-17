classdef TestFindExecutable < matlab.unittest.TestCase
    % TestFindExecutable - where ndi.fun.findExecutable looks, and in what order.
    %
    % Hermetic: dummy programs in a temp folder, a made-up program name
    % no real machine has (so /usr/bin and the login shell cannot answer),
    % a test-only environment variable, and the one preference used is
    % emptied for the test and restored after.

    properties
        Root
        Name
        SavedPref
    end

    properties (Constant)
        Pref = 'Tools.FFmpegPath'
        EnvVar = 'NDI_TEST_FIND_EXECUTABLE_HOME'
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            testCase.Name = sprintf('ndiFakeProg%d', randi(1e9));
            testCase.applyFixture(EnvironmentVariableFixture(testCase.EnvVar, ''));

            testCase.SavedPref = ndi.preferences.get(testCase.Pref);
            ndi.preferences.set(testCase.Pref, "");
            testCase.addTeardown(@() ndi.preferences.set(testCase.Pref, testCase.SavedPref));

            ndi.fun.findExecutable('clear');
            testCase.addTeardown(@() ndi.fun.findExecutable('clear'));
        end
    end

    methods (Access = private)
        function f = touch(testCase, varargin)
            % A dummy program: findExecutable only checks that it exists.
            f = fullfile(testCase.Root, varargin{:});
            folder = fileparts(f);
            if ~isfolder(folder)
                mkdir(folder);
            end
            fid = fopen(f, 'w');
            testCase.assertGreaterThan(fid, 0);
            fclose(fid);
        end

        function d = folder(testCase, varargin)
            d = fullfile(testCase.Root, varargin{:});
        end
    end

    methods (Test)

        function testExplicitPathWins(testCase)
            mine = testCase.touch('mine', 'myProgram');
            testCase.touch('a', testCase.Name);
            ndi.preferences.set(testCase.Pref, string(testCase.touch('p', testCase.Name)));
            got = ndi.fun.findExecutable(testCase.Name, 'Path', mine, ...
                'Preference', testCase.Pref, 'Folders', string(testCase.folder('a')));
            testCase.verifyEqual(got, mine);
        end

        function testAMissingExplicitPathIsAnError(testCase)
            testCase.verifyError(@() ndi.fun.findExecutable(testCase.Name, ...
                'Path', testCase.folder('nothere', testCase.Name)), ...
                'ndi:fun:findExecutable:badPath');
        end

        function testPreferenceBeatsEnvironmentAndFolders(testCase)
            want = testCase.touch('p', testCase.Name);
            ndi.preferences.set(testCase.Pref, string(want));
            setenv(testCase.EnvVar, testCase.touch('env', testCase.Name));
            testCase.touch('a', testCase.Name);
            got = ndi.fun.findExecutable(testCase.Name, 'Preference', testCase.Pref, ...
                'EnvironmentVariables', string(testCase.EnvVar), ...
                'Folders', string(testCase.folder('a')));
            testCase.verifyEqual(got, want);
        end

        function testAPreferenceForAMissingFileIsSkipped(testCase)
            ndi.preferences.set(testCase.Pref, string(testCase.folder('nothere', 'x')));
            want = testCase.touch('a', testCase.Name);
            got = ndi.fun.findExecutable(testCase.Name, 'Preference', testCase.Pref, ...
                'Folders', string(testCase.folder('a')));
            testCase.verifyEqual(got, want);
        end

        function testEnvironmentVariableMayNameTheProgram(testCase)
            want = testCase.touch('env', 'anyName');
            setenv(testCase.EnvVar, want);
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, ...
                'EnvironmentVariables', string(testCase.EnvVar)), want);
        end

        function testEnvironmentVariableMayNameItsFolder(testCase)
            want = testCase.touch('env', testCase.Name);
            setenv(testCase.EnvVar, testCase.folder('env'));
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, ...
                'EnvironmentVariables', string(testCase.EnvVar)), want);
        end

        function testEnvironmentVariableMayNameAHomeWithBin(testCase)
            % R_HOME style: the program is in <value>/bin.
            want = testCase.touch('rhome', 'bin', testCase.Name);
            setenv(testCase.EnvVar, testCase.folder('rhome'));
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, ...
                'EnvironmentVariables', string(testCase.EnvVar)), want);
        end

        function testEnvironmentBeatsFolders(testCase)
            want = testCase.touch('env', testCase.Name);
            setenv(testCase.EnvVar, testCase.folder('env'));
            testCase.touch('a', testCase.Name);
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, ...
                'EnvironmentVariables', string(testCase.EnvVar), ...
                'Folders', string(testCase.folder('a'))), want);
        end

        function testFoldersAreSearchedInOrder(testCase)
            testCase.touch('b', testCase.Name);
            want = testCase.touch('a', testCase.Name);
            got = ndi.fun.findExecutable(testCase.Name, 'Folders', ...
                [string(testCase.folder('empty')), string(testCase.folder('a')), ...
                 string(testCase.folder('b'))]);
            testCase.verifyEqual(got, want);
        end

        function testAWildcardFolderPrefersTheNewestName(testCase)
            testCase.touch('R', 'R-4.3.0', 'bin', testCase.Name);
            want = testCase.touch('R', 'R-4.4.1', 'bin', testCase.Name);
            testCase.touch('R', 'R-4.1.2', 'bin', testCase.Name);
            got = ndi.fun.findExecutable(testCase.Name, 'Folders', ...
                string(fullfile(testCase.Root, 'R', 'R-*', 'bin')));
            testCase.verifyEqual(got, want);
        end

        function testResultIsCachedUntilCleared(testCase)
            a = testCase.touch('a', testCase.Name);
            b = testCase.touch('b', testCase.Name);
            fa = string(testCase.folder('a'));
            fb = string(testCase.folder('b'));
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, 'Folders', fa), a);
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, 'Folders', fb), a, ...
                'a found program is remembered for the session');
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, 'Folders', fb, ...
                'Refresh', true), b, 'Refresh searches again');
            ndi.fun.findExecutable('clear');
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, 'Folders', fa), a);
        end

        function testACachedPathThatVanishedIsSearchedAgain(testCase)
            a = testCase.touch('a', testCase.Name);
            b = testCase.touch('b', testCase.Name);
            both = [string(testCase.folder('a')), string(testCase.folder('b'))];
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, 'Folders', both), a);
            delete(a);
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, 'Folders', both), b);
        end

        function testWindowsLooksForExe(testCase)
            testCase.touch('a', testCase.Name);
            want = testCase.touch('a', [testCase.Name '.exe']);
            testCase.verifyEqual(ndi.fun.findExecutable(testCase.Name, ...
                'IsWindows', true, 'Folders', string(testCase.folder('a'))), want);
        end

        function testNotFoundGivesTheInstallHint(testCase)
            try
                ndi.fun.findExecutable(testCase.Name, 'InstallHint', 'Install it with X.');
                testCase.verifyFail('findExecutable should have raised.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'ndi:fun:findExecutable:notFound');
                testCase.verifySubstring(ME.message, testCase.Name);
                testCase.verifySubstring(ME.message, 'Install it with X.');
            end
        end

        function testFindsThroughTheStandardFoldersOrShell(testCase)
            testCase.assumeFalse(ispc, 'Uses POSIX folders.');
            p = ndi.fun.findExecutable('sh');
            testCase.verifyTrue(isfile(p), p);
            [~, name] = fileparts(p);
            testCase.verifyEqual(name, 'sh');
        end

        function testUnsafeNamesAreRefusedBeforeAnyShell(testCase)
            bad = {'a b', 'x;rm', '../ffmpeg', 'ffmpeg.exe', '$(id)', 'a''b'};
            for i = 1:numel(bad)
                testCase.verifyError(@() ndi.fun.findExecutable(bad{i}), ...
                    'ndi:fun:findExecutable:invalidName', bad{i});
            end
        end
    end
end
