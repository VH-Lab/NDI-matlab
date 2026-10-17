classdef TestSystemCommandLine < matlab.unittest.TestCase
    % TestSystemCommandLine - external programs get one quoted argument each.

    methods (Test)

        function testPosixQuotesEveryArgument(testCase)
            c = ndi.fun.systemCommandLine('/opt/my tools/ffmpeg', ...
                {'-i', '/data/it''s here.avi'}, 'IsWindows', false, ...
                'CleanLibraryPath', false);
            testCase.verifyEqual(c, ['''/opt/my tools/ffmpeg'' ''-i'' ' ...
                '''/data/it''\''''s here.avi''']);
        end

        function testPosixRestoresTheLibraryPath(testCase)
            testCase.assumeFalse(ispc, 'POSIX prefix.');
            c = ndi.fun.systemCommandLine('/usr/bin/ffmpeg', {'-version'}, ...
                'IsWindows', false);
            testCase.verifyTrue(startsWith(c, 'LD_LIBRARY_PATH="'), c);
            testCase.verifyTrue(endsWith(c, '''/usr/bin/ffmpeg'' ''-version'''), c);
        end

        function testWindowsWrapsTheLineForCmd(testCase)
            % cmd /c strips the outer pair, leaving the quoted program.
            c = ndi.fun.systemCommandLine('C:\Program Files\R\R-4.4.1\bin\Rscript.exe', ...
                ["C:\Users\A B\x.R", 'say "hi"'], 'IsWindows', true);
            testCase.verifyEqual(c, ['""C:\Program Files\R\R-4.4.1\bin\Rscript.exe" ' ...
                '"C:\Users\A B\x.R" "say ""hi""""']);
        end

        function testArgumentsArriveIntact(testCase)
            testCase.assumeFalse(ispc, 'Runs a POSIX program.');
            raw = 'it''s "a" b $HOME';
            [status, out] = system(ndi.fun.systemCommandLine( ...
                ndi.fun.findExecutable('printf'), {'%s', raw}));
            testCase.verifyEqual(status, 0);
            testCase.verifyEqual(out, raw);
        end
    end
end
