classdef TestLaunchViewer < matlab.unittest.TestCase
    % TestLaunchViewer - the napari viewer is launched with its log kept.
    %
    % A viewer launched from MATLAB has no terminal, so its stdout and
    % stderr -- which tiles it fetched, what failed and why -- go to
    % lightsheet_YYYYMMDDHHMMSS.txt in NDI's temporary folder, with
    % NDI_LIGHTSHEET_DEBUG=1 so the debugging lines are in it.
    % viewerShellCommand and viewerLogFile are pure and tested on every
    % platform; launchViewer runs a stand-in launcher on POSIX.

    methods (Test)

        function testLogFileIsNamedByLaunchTimeInNdiTemp(testCase)
            when = datetime(2026, 10, 12, 9, 5, 7);
            f = ndi.fun.doc.lightsheet.viewerLogFile(when);
            testCase.verifyEqual(f, fullfile(ndi.common.PathConstants.TempFolder, ...
                'lightsheet_20261012090507.txt'));
        end

        function testPosixDetachedDebugCommand(testCase)
            c = ndi.fun.doc.lightsheet.viewerShellCommand( ...
                '/usr/local/bin/napariViewLightsheet ''/s'' --pyramid p', ...
                '/tmp/nditemp/lightsheet_1.txt', false, true, false);
            testCase.verifyEqual(c, ['NDI_LIGHTSHEET_DEBUG=1 ' ...
                '/usr/local/bin/napariViewLightsheet ''/s'' --pyramid p ' ...
                '>>''/tmp/nditemp/lightsheet_1.txt'' 2>&1 &']);
        end

        function testPosixWaitWithoutDebug(testCase)
            c = ndi.fun.doc.lightsheet.viewerShellCommand('v', '/tmp/l.txt', ...
                true, false, false);
            testCase.verifyEqual(c, 'v >>''/tmp/l.txt'' 2>&1');
        end

        function testPosixQuotesALogPathWithAQuote(testCase)
            c = ndi.fun.doc.lightsheet.viewerShellCommand('v', '/tmp/it''s.txt', ...
                true, false, false);
            testCase.verifyEqual(c, 'v >>''/tmp/it''\''''s.txt'' 2>&1');
        end

        function testWindowsDetachedDebugCommand(testCase)
            c = ndi.fun.doc.lightsheet.viewerShellCommand( ...
                '"C:\ndi\napariViewLightsheet.bat" "C:\s" --pyramid p', ...
                'C:\Temp\nditemp\lightsheet_1.txt', false, true, true);
            testCase.verifyEqual(c, ['start "napari" /min cmd /c "' ...
                'set NDI_LIGHTSHEET_DEBUG=1&& ' ...
                '"C:\ndi\napariViewLightsheet.bat" "C:\s" --pyramid p ' ...
                '>>"C:\Temp\nditemp\lightsheet_1.txt" 2>&1"']);
        end

        function testWindowsWaitRunsInPlace(testCase)
            c = ndi.fun.doc.lightsheet.viewerShellCommand('v', 'C:\l.txt', ...
                true, true, true);
            testCase.verifyEqual(c, 'set NDI_LIGHTSHEET_DEBUG=1&& v >>"C:\l.txt" 2>&1');
        end

        function testLaunchWritesHeaderOutputAndDebugFlag(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX stand-in launcher.');
            folder = tempname;
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            launcher = fullfile(folder, 'fakeViewer.sh');
            fid = fopen(launcher, 'w');
            fprintf(fid, '#!/bin/sh\necho "debug=$NDI_LIGHTSHEET_DEBUG args=$*"\necho "to stderr" >&2\n');
            fclose(fid);
            system(['chmod +x ''' launcher '''']);
            logFile = fullfile(folder, 'sub', 'lightsheet_test.txt');

            [status, got, fullCmd] = ndi.fun.doc.lightsheet.launchViewer( ...
                [launcher ' --pyramid p1'], 'wait', true, ...
                'logFile', logFile, 'verbose', false);

            testCase.verifyEqual(status, 0);
            testCase.verifyEqual(got, logFile);
            testCase.verifySubstring(fullCmd, 'NDI_LIGHTSHEET_DEBUG=1');
            text = fileread(logFile);
            testCase.verifySubstring(text, '=== napari lightsheet viewer:');
            testCase.verifySubstring(text, ['command : ' launcher ' --pyramid p1']);
            testCase.verifySubstring(text, 'debug=1 args=--pyramid p1');
            testCase.verifySubstring(text, 'to stderr');
        end

        function testASecondLaunchAppendsRatherThanOverwrites(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX command.');
            logFile = [tempname '.txt'];
            testCase.addTeardown(@() delete(logFile));
            ndi.fun.doc.lightsheet.launchViewer('echo first', 'wait', true, ...
                'logFile', logFile, 'verbose', false);
            ndi.fun.doc.lightsheet.launchViewer('echo second', 'wait', true, ...
                'logFile', logFile, 'verbose', false);
            text = fileread(logFile);
            testCase.verifySubstring(text, 'first');
            testCase.verifySubstring(text, 'second');
        end

        function testTheManagerLaunchesThroughLaunchViewer(testCase)
            % The View dialog must keep the log too, not just the
            % command-line helper.
            src = fileread(which('ndi.gui.app.LightsheetZarrManager'));
            testCase.verifySubstring(src, 'ndi.fun.doc.lightsheet.launchViewer(cmd)');
            src = fileread(which('ndi.fun.doc.lightsheet.view'));
            testCase.verifySubstring(src, 'ndi.fun.doc.lightsheet.launchViewer(cmd');
        end
    end
end
