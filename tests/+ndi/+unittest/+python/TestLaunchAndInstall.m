classdef TestLaunchAndInstall < matlab.unittest.TestCase
    % TestLaunchAndInstall - how MATLAB starts NDI-python's commands and its installer.
    %
    % The command builders are pure and are checked for both shells on
    % every platform. The runs use stand-in scripts in a temp folder (a
    % folder name with a space in it, as Windows user folders have):
    % nothing is downloaded and the real installer is never run.

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.Root = fullfile(tempname, 'my tools');
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(fileparts(testCase.Root), 's'));
        end
    end

    methods (Access = private)
        function f = writeScript(testCase, fileName, body)
            f = fullfile(testCase.Root, fileName);
            fid = fopen(f, 'w');
            testCase.assertGreaterThan(fid, 0);
            fprintf(fid, '%s', body);
            fclose(fid);
            if ~ispc
                system(['chmod +x ' ndi.python.shellQuote(f)]);
            end
        end
    end

    methods (Test)

        function testEnvironmentPrefixForEachShell(testCase)
            testCase.verifyEqual(ndi.python.environmentPrefix('IsWindows', false), ...
                'NDI_FROM_MATLAB=1 ');
            testCase.verifyEqual(ndi.python.environmentPrefix('IsWindows', true), ...
                'set NDI_FROM_MATLAB=1&& ');
        end

        function testShellQuoteForEachShell(testCase)
            testCase.verifyEqual(ndi.python.shellQuote('/a b/it''s', 'IsWindows', false), ...
                '''/a b/it''\''''s''');
            testCase.verifyEqual(ndi.python.shellQuote('C:\Users\A B\x"y', 'IsWindows', true), ...
                '"C:\Users\A B\x""y"');
        end

        function testPosixCommandLineIsDetachedAndMarked(testCase)
            c = ndi.python.commandLine('/home/a b/.ndi/bin/ndi', {'--session', '/s 1'}, ...
                'IsWindows', false);
            testCase.verifyEqual(c, ['NDI_FROM_MATLAB=1 ''/home/a b/.ndi/bin/ndi'' ' ...
                '''--session'' ''/s 1'' &']);
        end

        function testPosixCommandLineCanWait(testCase)
            c = ndi.python.commandLine('/x/ndi', {}, 'IsWindows', false, 'Wait', true);
            testCase.verifyEqual(c, 'NDI_FROM_MATLAB=1 ''/x/ndi''');
        end

        function testWindowsCommandLineIsDetachedAndMarked(testCase)
            c = ndi.python.commandLine('C:\Users\A B\.ndi\bin\ndi.exe', "--help", ...
                'IsWindows', true, 'Title', 'ndi');
            testCase.verifyEqual(c, ['set NDI_FROM_MATLAB=1&& start "ndi" /min ' ...
                '"C:\Users\A B\.ndi\bin\ndi.exe" "--help"']);
        end

        function testWindowsCommandLineCanWait(testCase)
            c = ndi.python.commandLine('C:\x\ndi.exe', {'a'}, 'IsWindows', true, 'Wait', true);
            testCase.verifyEqual(c, 'set NDI_FROM_MATLAB=1&& "C:\x\ndi.exe" "a"');
        end

        function testInstallerCommandPosix(testCase)
            c = ndi.python.installerCommand('/tmp/a b/install-ndi.sh', 'IsWindows', false);
            testCase.verifyTrue(endsWith(c, '/bin/sh ''/tmp/a b/install-ndi.sh'' --yes'), c);
            c = ndi.python.installerCommand('/tmp/i.sh', 'IsWindows', false, ...
                'Uninstall', true, 'AddToPath', false);
            testCase.verifyTrue(endsWith(c, '/bin/sh ''/tmp/i.sh'' --yes --uninstall --no-path'), c);
        end

        function testInstallerCommandWindows(testCase)
            c = ndi.python.installerCommand('C:\T\install-ndi.ps1', 'IsWindows', true);
            testCase.verifyEqual(c, ['powershell -NoProfile -ExecutionPolicy Bypass ' ...
                '-File "C:\T\install-ndi.ps1" -Yes']);
            c = ndi.python.installerCommand('C:\T\i.ps1', 'IsWindows', true, ...
                'Uninstall', true, 'AddToPath', false);
            testCase.verifyEqual(c, ['powershell -NoProfile -ExecutionPolicy Bypass ' ...
                '-File "C:\T\i.ps1" -Yes -Uninstall -NoPath']);
        end

        function testLaunchSetsTheVariableAndKeepsSpaces(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in.');
            out = fullfile(testCase.Root, 'out file.txt');
            tool = testCase.writeScript('fakeTool', ...
                sprintf('#!/bin/sh\necho "from=$NDI_FROM_MATLAB n=$#" > "$1"\n'));
            [status, cmd] = ndi.python.launch('fakeTool', {out}, ...
                'Launcher', tool, 'Wait', true, 'Verbose', false);
            testCase.verifyEqual(status, 0, cmd);
            testCase.verifyEqual(strtrim(fileread(out)), 'from=1 n=1');
        end

        function testInstallRunsTheScriptAndReturnsTheBinFolder(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in installer.');
            testCase.writeScript('install-ndi.sh', sprintf([ ...
                '#!/bin/sh\n' ...
                'echo "args: $*"\n' ...
                'echo "NDI installed: /fake home/.ndi/bin"\n']));
            got = ndi.python.install('Source', testCase.Root, 'AddToPath', false);
            testCase.verifyEqual(got, '/fake home/.ndi/bin');
        end

        function testInstallPassesTheFlags(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in installer.');
            testCase.writeScript('install-ndi.sh', sprintf([ ...
                '#!/bin/sh\n' ...
                'echo "args: $*"\n' ...
                'exit 7\n']));
            try
                ndi.python.install('Source', testCase.Root, 'Uninstall', true, ...
                    'AddToPath', false);
                testCase.verifyFail('install should have raised.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'ndi:python:installFailed');
                testCase.verifySubstring(ME.message, 'args: --yes --uninstall --no-path');
                testCase.verifySubstring(ME.message, 'status 7');
            end
        end

        function testInstallClearsTheCommandCache(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in installer.');
            name = sprintf('ndiFakeTool%d', randi(1e9));
            a = fullfile(testCase.Root, 'a');
            b = fullfile(testCase.Root, 'b');
            mkdir(a); mkdir(b);
            fclose(fopen(fullfile(a, name), 'w'));
            fclose(fopen(fullfile(b, name), 'w'));
            testCase.applyFixture(EnvironmentVariableFixture('NDI_PYTHON_BIN', a));
            testCase.addTeardown(@() ndi.python.clearCommandCache());
            ndi.python.clearCommandCache();
            testCase.verifyEqual(ndi.python.findCommand(name), fullfile(a, name));

            setenv('NDI_PYTHON_BIN', b);
            testCase.writeScript('install-ndi.sh', sprintf([ ...
                '#!/bin/sh\n' ...
                'echo "NDI installed: %s"\n'], b));
            ndi.python.install('Source', testCase.Root);
            testCase.verifyEqual(ndi.python.findCommand(name), fullfile(b, name));
        end
    end
end
